module Node
    ( Node
    , NodeType ( .. )
    , RectDef
    , TextDef
    , Size
    , ISize
    , ISizes
    , Ratio
    , Direction ( .. )
    , Extent ( .. )
    , Align ( .. )
    , BorderStyle
    , Which
    , extentIsFill
    , extentIsFix
    , fixSize
    ) where

import Color exposing ( Color )
import Maybe exposing ( map, withDefault )

-- NODE TYPES

type alias Node =
    { nodeType : NodeType
    }

type NodeType = Rect RectDef
    | Text TextDef

type alias RectDef =
    { extents : ( Extent, Extent )
    , dir : Direction
    , border : Maybe BorderStyle
    , children : List Node
    }

-- Text extents are always ( Fit, Fit )
type alias TextDef =
    { text : String
    }

-- NODE PROPERTIES

type alias Size = Float
type alias ISize = Int
type alias ISizes = ( ISize, ISize )
type alias Ratio = Float

type Direction = Up | Down | Left | Right | In | Out

type Extent =
    Fix Size
    | Fit
    | Fill Ratio

type Align = TopLeft | TopMiddle | TopRight
    | MiddleLeft | Middle | MiddleRight
    | BottomLeft | BottomMiddle | BottomRight

{- Directional property that can be defined once, twice or four times for 
distinct directions -}
type DirProp a = Same a
    | SameDir a a
    | Distinct a a a a

type alias BorderStyle = 
    { thickness : Size --TODO DirProp Size
    , color : Color
    }

-- HELPER FNS

type alias Which a = ( a, a ) -> a

extentIsFill : Which Extent -> Node -> Bool
extentIsFill which node = which `extentOf` node |> isFill

extentIsFix : Which Extent -> Node -> Bool
extentIsFix which node = which `extentOf` node |> isFix

fixSize : Which Extent -> Node -> Float
fixSize which node = which `extentOf` node |> map fixSize' |> withDefault 0.0

-- INTERNAL

extentOf : Which Extent -> Node -> Maybe Extent
extentOf which node = case node.nodeType of
        Rect def -> which def.extents |> Just
        _ -> Nothing

isFill extent = withDefault False <| map isFill' extent

isFill' extent = case extent of
        Fill _ -> True
        _ -> False

isFix extent = withDefault False <| map isFix' extent

isFix' extent = case extent of
        Fix _ -> True
        _ -> False

fixSize' : Extent -> Float
fixSize' extent = case extent of
        Fix h -> h
        _ -> 0.0

