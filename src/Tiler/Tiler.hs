{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedLabels #-}


{- |
    In here you'll find most of the interesting pure code for Xest. This code
    makes heavy use of recursions schemes (cata, ana, etc.) and lacks
    explicit recursion.
-}

module Tiler.Tiler
  ( module Tiler.Tiler
  , module Tiler.TilerTypes
  , module Tiler.ParentChild
  , module Tiler.TreeCombo
  , module Tiler.Sized
  , module Tiler.BottomOrTop
  )
where

import           Standard
import           Graphics.X11.Types
import           Tiler.TilerTypes
import           Tiler.ParentChild
import           Tiler.TreeCombo
import           Tiler.Sized
import           Tiler.BottomOrTop
import           FocusList
import           Data.Functor.Foldable          ( embed )


-- | Add a new Tiler wherever it would make the most sense to the user. For
-- example, it's placed at the back for Horiz.
add :: SubTiler -> Tiler -> Tiler
add w (Horiz    fl) = traceShowId $ Horiz $ multiPush Back Focused (Sized 0 w) fl
-- TODO I could try to make the Rectangle float with whatever size the window
-- is asking for, but that requires doing IO. Is it worth it?
add w (Floating ls) = Floating $ Top (Rect 0 0 300 300, w) +: ls
add w t             = Horiz $ multiPush Back Focused (Sized 0 w) $ point (Sized 0 $ Fix t)


-- | Remove a Window if it exists in the tree.
ripOut :: Window -> Tiler -> Tiler
ripOut toDelete = project . fromMaybe (error "No root!") . cata isEqual
 where
  isEqual :: TilerF (Maybe SubTiler) -> Maybe SubTiler
  isEqual (Wrap (ParentChild parent window))
    | window == toDelete = Nothing
    | otherwise          = Just . embed . Wrap $ ParentChild parent window
  isEqual t = coerce $ reduce t



-- | Removes empty Tilers
reduce :: TilerF (Maybe SubTiler) -> Maybe Tiler
-- Yo dog, I head you like fmap
-- on a serious note, these two cases are super unreadable TODO
reduce (Horiz fl) =
  Horiz <$> toNonEmptyML (catMaybes $ fmap sequence $ MLE fl)
reduce (Floating ls) = newTiler
 where
  newTiler =
    Floating . fmap (fmap $ fromMaybe (error "Impossible")) <$> newFront
  newFront = filterNe (not . null . getEither) ls
reduce (InputControllerOrMonitor c t) = Just . c $ join t
reduce (Reflect   t                 ) = fmap Reflect t
reduce (FocusFull t                 ) = fmap FocusFull t
reduce (Wrap      w                 ) = Just $ Wrap w


-- | A combination of top and pop if you're coming from c++.
-- fst . popWindow is like top and snd . popWindow is like pop
popWindow
  :: Show a => Either Direction Focus -> TilerF a -> (a, Maybe (TilerF a))

popWindow howToPop (Horiz    fl) =
  let flNode = view (endOf howToPop) fl
   in (getItem $ flNodeElement flNode, Horiz <$> toNonEmptyML (multiRemove flNode fl))

popWindow howToPop (Floating ls) = second (fmap Floating) $ case howToPop of
  Right Unfocused -> (getEither $ last ls, init ls)
  _               -> (getEither $ head ls, tail ls)

popWindow _ (Reflect   t) = (t, Nothing)
popWindow _ (FocusFull t) = (t, Nothing)

popWindow e t =
  error $ "Attempted to pop the unpopable" ++ show e ++ " " ++ show t


-- |Get's the focused window. Throws an error if it can't. This little function
-- is the primary cause of runtime errors that aren't related to Xorg. Usually,
-- an unpopable error means you called getFocused when you shouldn't have.
getFocused :: Show a => TilerF a -> a
getFocused = fst . popWindow (Right Focused)



-- | Given something that wants to modify a Tiler,
-- apply it to the first Tiler after the inputController.
applyInput :: (Maybe SubTiler -> Maybe SubTiler) -> Tiler -> Tiler
applyInput f = toFType . cata \case
  InputController t -> InputController $ f t
  t                   -> coerce t

-- |Kind of like applyInput but can be used to get arbitrary info out of
-- focused element.
onInput :: (Maybe SubTiler -> a) -> Tiler -> a
onInput f root = f $ extract $ ana @(Beam _) findIC $ coerce root
 where
  findIC :: SubTiler -> BeamF (Maybe SubTiler) SubTiler
  findIC (InputController t       ) = EndF t
  findIC (Monitor         Nothing ) = EndF Nothing
  findIC (Monitor         (Just t)) = ContinueF t
  findIC t                          = ContinueF $ getFocused $ coerce t

-- | Kind of like applyInput but instead of searching for the InputController,
-- it just applies the function to whatever is focused by an individual Tiler.
modFocused :: (a -> a) -> TilerF a -> TilerF a
modFocused f (Horiz fl) = Horiz $ over (endOf (Right Focused) % #element) (fmap f) fl
modFocused f (   Floating  (NE a as)         ) = Floating $ NE (fmap f a) as
modFocused f (   Reflect   t                 ) = Reflect $ f t
modFocused f (   FocusFull t                 ) = FocusFull $ f t
modFocused _ wp@(Wrap      _                 ) = wp
modFocused f t@( InputControllerOrMonitor _ _) = fmap f t


-- | Change the focus of a Tiler
focus :: (a -> Bool) -> TilerF a -> TilerF a
focus newF (  Horiz           fl) =
  Horiz $ modPointer (Right Focused) (newF . getItem . flNodeElement) fl
focus newF (Floating ls) = Floating $ moveF 0 (newF . getEither) ls
focus _    t@(Wrap            _ ) = t
focus _    t@(Reflect         _ ) = t
focus _    t@(FocusFull       _ ) = t
focus _    t@(InputController _ ) = t
focus _    t@(Monitor         _ ) = t

-- |Sometimes, we end up with a tree that's in an invalid state.
-- Usually, we can fix that by finding the closest parent between
-- two nodes and moving one of the nodes there. This function
-- implements that logic.
--
-- In addition to moving the node, this function also ensures that
-- the movable node is always a parent of the unmovable node.
moveToClosestParent
  :: (TilerF (Maybe SubTiler) -> Bool) -- |Function used to find the unmovable part
  -> (TilerF (Maybe SubTiler) -> Maybe (Reparenter, Unparented)) -- |Function used to find the movable part.
  -> Tiler
  -> (Maybe Tiler, TreeCombo)
moveToClosestParent predicateUnmove predicateMove = coerce
  . cata (coerce . moveToClosestParent')
 where
  moveToClosestParent'
    :: TilerF (Maybe SubTiler, TreeCombo) -> (Maybe Tiler, TreeCombo)
  moveToClosestParent' t
    | predicateUnmove $ fmap fst t =
      -- We are looking at the unmovable part
      case asum $ fmap (getMovable . snd) t of
        -- We haven't seen the movable part, so just set the Unmovable flag and be done
        Nothing -> (withNewFocus t, Unmovable)
        -- We already saw the movable part so add that in as this thing's parents
        Just (reparentFunction, _) ->
          (Just $ reparentFunction $ coerce $ withNewFocus t, Both)
    | otherwise = case predicateMove $ fmap fst t of
        -- Whatever we found, it's neither of the parts. It might be the parent though.
      Nothing -> case hasBothIndividually t of
          -- We found the parent! Let's make it the parent.
        Just (reparentFunction, _) ->
          (Just $ reparentFunction $ coerce $ withNewFocus t, Both)
        -- This node is uneventful. Let's just make sure its focus is correct
        Nothing -> (withNewFocus t, foldMap snd t)
      -- We found the movable part!
      Just functions@(_, unparented) -> if any (isUnmovable . snd) t
                                          -- If it already contained the unmovable part, we're done!
        then (withNewFocus t, Both)
                                          -- Otherwise, let's remove it and set the right flag
        else (unparented, Movable functions)
  withNewFocus :: TilerF (Maybe SubTiler, TreeCombo) -> Maybe Tiler
  withNewFocus t =
    reduce $ fmap fst $ focus (\(_, tc) -> isUnmovable tc || isBoth tc) t
  hasBothIndividually tiler = if any (isUnmovable . snd) tiler
    then asum $ fmap (getMovable . snd) tiler
    else Nothing

-- |Specialization of the above for moving an InputController towards a window
moveToWindow :: Window -> Tiler -> (Maybe Tiler, Bool)
moveToWindow window =
  second isBoth . moveToClosestParent isWindow isInputController
 where
  isInputController :: TilerF (Maybe SubTiler) -> Maybe (Reparenter, Unparented)
  isInputController (InputController (t :: Maybe (Maybe SubTiler))) =
    Just (InputController, coerce $ join t)
  isInputController _ = Nothing
  isWindow (Wrap parentChild) = inParentChild window parentChild
  isWindow _                  = False

-- |Specialization of the above for moving a moniter towards the inputController
moveToIC :: Tiler -> (Maybe Tiler, Bool)
moveToIC = second isBoth . moveToClosestParent isInputController isMonitor
 where
  isMonitor (Monitor t) = Just (Monitor, coerce $ join t)
  isMonitor _           = Nothing
  isInputController (InputController _) = True
  isInputController _                   = False

-- |Do both of the above in sequence. This is the function that's actually used elsewhere
focusWindow :: Window -> Tiler -> Maybe Tiler
focusWindow window root =
  let (newRoot   , b1) = moveToWindow window root
      (newestRoot, b2) = maybe (Nothing, False) moveToIC newRoot
  in  if b1 && b2 then newestRoot else Nothing

-- |The EWMH says window managers can list the number of virtual desktops and
-- their names. This function gets that info, although we use a liberal
-- definition of virtual desktop.
getDesktopState :: Tiler -> ([Text], Int)
getDesktopState (Horiz fl) = (pack . show <$> [1 .. length fl], i)
  where i = view (#focEnds % _1) fl
getDesktopState _ = (["None"], 0)

-- |Renders the tree to a string which can be displayed on the top border of
-- Xest.
getFocusList :: TilerF String -> String
getFocusList (InputController s       ) = "*" ++ fromMaybe "" s
getFocusList (Monitor         s       ) = "@" ++ fromMaybe "" s
getFocusList (Horiz fl) = "Horiz|" ++ getItem (view (endOf (Right Focused) % #element) fl)
getFocusList (Floating        (NE t _)) = "Floating|" ++ extract t
getFocusList (Reflect         t       ) = "Rotate|" ++ t
getFocusList (FocusFull       t       ) = "Full|" ++ t
getFocusList (Wrap            _       ) = "Window"

-- |Given a child, can we find the parent in our tree?
findParent :: Window -> Tiler -> Maybe Window
findParent w = cata step
 where
  step (Wrap (ParentChild ww ww')) | ww' == w  = Just ww
                                   | otherwise = Nothing
  step t = foldl' (<|>) Nothing t

-- |Do some geometry to figure out which screen we're on. What's up with the
-- Functor f getting tossed around? Well sometimes we want the actual screen
-- that's focused and other times we want just the index. This function can do
-- both of those. If you're looking for just the element, f ~ Identity but if
-- you're looking for the index, f ~ (Int,).
whichScreen
  :: (Eq (f Bool), Functor f) => (Int32, Int32) -> [f XRect] -> Maybe (f XRect)
whichScreen (mx, my) = getFirst . foldMap findOverlap
 where
  findOverlap wrapped =
    if (wrapped $> True) == fmap inside wrapped then return wrapped else mempty
  inside Rect {..} =
    mx >= x && my >= y && mx < x + fromIntegral w && my < y + fromIntegral h

-- |The monitor must always be in the focus path.
-- If it's already there, this function does nothing.
fixMonitor :: Tiler -> Tiler
fixMonitor root = if cata isInPath root
  then root
  else maybe (error "Uh oh") unfix $ insertMonitor root
     -- TODO Haskell's Complete pragma doesn't work when the cata is in isInPath.
     -- Although the Complete pragma just doesn't work on 8.6.5.


 where
  isInPath :: TilerF Bool -> Bool
  isInPath = \case
    Monitor         _ -> True
    Wrap            _ -> False
    InputController t -> fromMaybe False t
    FocusFull       t -> t
    Reflect         t -> t
    t@(Horiz    _)    -> getFocused t
    t@(Floating _)    -> getFocused t
  insertMonitor = cata $ \case
    Monitor t -> join t
    InputController t ->
      Just $ Fix $ Monitor $ Just $ Fix $ InputController $ join t
    t -> Fix <$> reduce t

findWindow :: Window -> Tiler -> Bool
findWindow w = cata $ \case
      (Wrap w') -> inParentChild w w'
      t -> or t