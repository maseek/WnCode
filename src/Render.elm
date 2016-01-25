module Render
    ( render
    ) where

import Node exposing ( .. )

import Graphics.Element exposing ( .. )
import Graphics.Collage exposing ( Form, collage, defaultLine, move, toForm )
import Window
import Text             exposing ( fromString )

render : Node -> Signal Element
render node = Signal.map ( renderRoot node ) Window.dimensions

-- INTERNAL

renderRoot : Node -> ISizes -> Element
renderRoot node sceneSize =
    case node.nodeType of
        Rect def -> 
            renderRect def sceneSize ( tupleMap ( toFloat >> Just ) sceneSize )
        Text def -> renderText def

tupleMap : ( a -> b ) -> ( a, a ) -> ( b, b )
tupleMap f ( x, y ) = ( f x, f y )

type alias MaybeSizes = ( Maybe Size, Maybe Size )

renderRect : RectDef -> ISizes -> MaybeSizes -> Element
renderRect def sceneSize parentSize =
    let borderSize = case def.border of
            Just bs -> bs.thickness * 2.0
            _ -> 0.0
        maybeSize = tupleMap2 tryToGetSize def.extents parentSize
        ( renderChildrenFn, moveChildrenFn ) = case def.dir of
            Up -> ( rendChildren Vert, moveChildren Vert True )
            Down -> ( rendChildren Vert, moveChildren Vert False )
            Left -> ( rendChildren Hori, moveChildren Hori True )
            Right -> ( rendChildren Hori, moveChildren Hori False )
            In -> ( rendStackChildren, moveStackChildren True )
            Out -> ( rendStackChildren, moveStackChildren False )
        ( children, childrenSize ) = 
            renderChildrenFn sceneSize 
                -- children size reduced by border size
                ( maybeSize |> tupleMap ( Maybe.map ( ( + ) -borderSize ) ) ) 
                def.children
        ( width, height ) = tupleMap2 getSize maybeSize childrenSize
        border = case def.border of
            Just bs -> renderRectBorder bs width height
            _ -> []
        borderSize' = ceiling borderSize
        -- children size reduced by border size
        cs = moveChildrenFn ( width - borderSize', height - borderSize' ) 
            children
        rend cs' = collage width height cs'
    in rend ( border ++ cs )

renderRectBorder : BorderStyle -> ISize -> ISize -> List Form
renderRectBorder bs width height = 
    [ ( Graphics.Collage.outlined 
        { defaultLine | color = bs.color, width = bs.thickness * 2.0 } 
        ( Graphics.Collage.rect ( toFloat width ) ( toFloat height ) ) ) ]

tupleMap2 : ( a -> b -> c ) -> ( a, a ) -> ( b, b ) -> ( c, c )
tupleMap2 f ( x, y ) ( w, z ) = ( f x w, f y z )

tryToGetSize : Extent -> Maybe Size -> Maybe Size
tryToGetSize extent parentSize = case extent of
            Fix s -> Just s
            Fit -> Nothing
            Fill ratio -> Maybe.map ( ( * ) ratio ) parentSize

getSize : Maybe Size -> Maybe Size -> ISize
getSize maybeSize childrenSize =
    Maybe.withDefault ( Maybe.withDefault 0.0 childrenSize ) maybeSize 
        |> ceiling

rendChildren : Side -> ISizes -> MaybeSizes -> List Node ->
   ( List Element, MaybeSizes )
rendChildren side sceneSize parentSize nodes =
    let ( fills, fixesAndFits ) = 
            List.partition ( ( onWhich side ) |> extentIsFill ) nodes
        fillCount = fills |> List.length
        adjOtherParentSize = 
            recalcParentSize side sceneSize parentSize fixesAndFits fillCount
        adjParentSize = case side of
            Hori -> ( adjOtherParentSize, snd parentSize )
            Vert -> ( fst parentSize, adjOtherParentSize )
        children = List.map ( renderChild sceneSize adjParentSize ) nodes
        childrenSize = List.map sizeOf children
        childrenW = List.map fst childrenSize |> List.maximum 
            |> Maybe.map toFloat
        childrenH = List.map snd childrenSize |> List.sum |> toFloat |> Just
    in ( children, ( childrenW, childrenH ) )
        
type Side = Vert | Hori

onWhich : Side -> Which a
onWhich side = case side of
        Hori -> fst
        Vert -> snd

rendStackChildren : ISizes -> MaybeSizes -> List Node ->
   ( List Element, MaybeSizes )
rendStackChildren sceneSize ( parentW, parentH ) nodes =
    let children = 
            List.map ( renderChild sceneSize ( parentW, parentH ) ) nodes
        childrenSize = List.map sizeOf children
        childrenW = List.map fst childrenSize |> List.maximum
            |> Maybe.map toFloat
        childrenH = List.map snd childrenSize |> List.maximum 
            |> Maybe.map toFloat
    in ( children, ( childrenW, childrenH ) )

recalcParentSize : Side -> ISizes -> MaybeSizes -> List Node -> Int 
        -> Maybe Size
recalcParentSize side sceneSize parentSize nodes fillCount =
    if fillCount == 0
        then ( onWhich side ) parentSize
        else
            let ( fixes, fits ) = 
                    List.partition ( ( onWhich side ) |> extentIsFix ) nodes
                fixesSize = 
                    List.map ( ( onWhich side ) |> fixSize ) fixes |> List.sum
                renderFits = List.map ( renderChild sceneSize parentSize ) fits
                fitsSize = List.foldr (+) 0.0 
                    <| List.map ( sizeOf >> ( onWhich side ) >> toFloat ) 
                    renderFits
                recalc size = ( size - fixesSize ) / ( toFloat fillCount )
            in Maybe.map ( \s -> if fillCount > 0 then recalc s else s ) 
                ( ( onWhich side ) parentSize )

renderChild : ISizes -> MaybeSizes -> Node -> 
    Element
renderChild sceneSize parentSize node =
     case node.nodeType of
        Rect def -> renderRect def sceneSize parentSize
        Text def -> renderText def

moveChildren : Side -> Bool -> ( ISize, ISize ) -> List Element -> List Form
moveChildren side reverse ( width, height ) children = 
    let childWOffset child = ( ( widthOf child ) - width |> toFloat ) * 0.5
        childHOffset child = ( height - ( heightOf child ) |> toFloat ) * 0.5
        -- returns the moved child and it's offset
        moveChild child offset = case side of
            Vert ->
                ( move ( childWOffset child, childHOffset child + offset ) 
                    ( toForm child )
                , offset - ( heightOf child |> toFloat ) )
            Hori ->
                ( move ( childWOffset child + offset, childHOffset child ) 
                    ( toForm child )
                , offset + ( widthOf child |> toFloat ) )
        fold = case reverse of
            True -> List.foldr
            False -> List.foldl
    in fold ( \x acc -> 
            ( moveChild x 
                -- get the offset from the previous child if any
                ( List.head acc |> Maybe.map snd |> Maybe.withDefault 0.0 ) 
            ) :: acc ) 
            [] children 
                -- throw away the offsets
                |> List.map fst

moveStackChildren : Bool -> ( ISize, ISize ) -> List Element -> List Form
moveStackChildren reverse ( width, height ) children = 
    let childWOffset child = ( ( widthOf child ) - width |> toFloat ) * 0.5
        childHOffset child = ( height - ( heightOf child ) |> toFloat ) * 0.5
        -- returns the moved child and it's offset
        moveChild child = 
            move ( childWOffset child, childHOffset child ) ( toForm child )
        cs = case reverse of
            True -> List.reverse children
            False -> children
    in List.map moveChild cs
                
renderText : TextDef -> Element
renderText def = fromString def.text |> leftAligned
