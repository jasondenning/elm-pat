module Tools.AddRelative
    exposing
        ( State
        , Config
        , svg
        , init
        , view
        )

import Dict
import Dropdown
import Html exposing (Html)
import Html.Attributes as Html
import Html.Events as Html
import Input.Float
import Math.Vector2 exposing (..)
import Svg exposing (Svg)
import Svg.Attributes as Svg
import Svg.Events as Svg


{- internal -}

import Events
import Svg.Extra as Svg
import Tools.Common exposing (..)
import Types exposing (..)


{- state -}


type alias State =
    WithMouse
        { id : Maybe String
        , x : Maybe Float
        , y : Maybe Float
        , focused : Maybe Id
        }


init : State
init =
    { id = Nothing
    , x = Nothing
    , y = Nothing
    , focused = Nothing
    , mouse = Nothing
    }



{- config -}


type alias Config msg =
    { addPoint : Point -> msg
    , stateUpdated : State -> msg
    , viewPort : ViewPort
    }


svg : Config msg -> State -> PointStore -> Svg msg
svg config state store =
    let
        anchorPosition =
            state.id
                |> Maybe.andThen (String.toInt >> Result.toMaybe)
                |> Maybe.andThen (flip Dict.get store)
                |> Maybe.andThen (position store)
    in
        case anchorPosition of
            Just v ->
                Svg.g []
                    [ case state.mouse of
                        Just position ->
                            drawCursor config state v position

                        Nothing ->
                            Svg.g [] []
                    , drawLines config state v
                    , drawNewPoint config state v
                    , eventRect config state store
                    ]

            Nothing ->
                Svg.g []
                    [ eventCircles config state store ]


drawCursor : Config msg -> State -> Vec2 -> Position -> Svg msg
drawCursor config state v p =
    let
        draw x y =
            Svg.g []
                [ Svg.drawPoint (vec2 x y)
                , Svg.drawSelector (vec2 x y)
                , Svg.drawRectArrow v (vec2 x y)
                ]
    in
        case ( state.x, state.y ) of
            ( Just x, Just y ) ->
                Svg.g [] []

            ( Just x, Nothing ) ->
                draw (getX v + x) (toFloat p.y)

            ( Nothing, Just y ) ->
                draw (toFloat p.x) (getY v + y)

            ( Nothing, Nothing ) ->
                draw (toFloat p.x) (toFloat p.y)


drawLines : Config msg -> State -> Vec2 -> Svg msg
drawLines config state v =
    case ( state.x, state.y ) of
        ( Just x, Just y ) ->
            Svg.g [] []

        ( Just x, Nothing ) ->
            let
                deltaX =
                    x + getX v
            in
                Svg.g []
                    [ Svg.drawVerticalLine deltaX ]

        ( Nothing, Just y ) ->
            let
                deltaY =
                    y + getY v
            in
                Svg.g []
                    [ Svg.drawHorizontalLine deltaY ]

        ( Nothing, Nothing ) ->
            Svg.g [] []


drawNewPoint : Config msg -> State -> Vec2 -> Svg msg
drawNewPoint config state v =
    case ( state.x, state.y ) of
        ( Just x, Just y ) ->
            let
                w =
                    (vec2 (getX v + x) (getY v + y))
            in
                Svg.g []
                    [ Svg.drawPoint w
                    , Svg.drawSelector w
                    , Svg.drawRectArrow v w
                    ]

        _ ->
            Svg.g [] []


eventRect : Config msg -> State -> PointStore -> Svg msg
eventRect config state store =
    case addPoint config state store of
        Just callback ->
            Svg.rect
                [ Svg.x (toString config.viewPort.x)
                , Svg.y (toString config.viewPort.y)
                , Svg.width (toString config.viewPort.width)
                , Svg.height (toString config.viewPort.height)
                , Svg.fill "transparent"
                , Svg.strokeWidth "0"
                , Events.onClick callback
                , Events.onMove
                    (updateMouse config.stateUpdated state config.viewPort << Just)
                , Svg.onMouseOut
                    (updateMouse config.stateUpdated state config.viewPort Nothing)
                ]
                []

        Nothing ->
            Svg.g [] []


eventCircles : Config msg -> State -> PointStore -> Svg msg
eventCircles config state store =
    Svg.g []
        (List.filterMap (eventCircle config state store) (Dict.toList store))


eventCircle : Config msg -> State -> PointStore -> ( Id, Point ) -> Maybe (Svg msg)
eventCircle config state store ( id, point ) =
    let
        draw v =
            Svg.g []
                [ Svg.circle
                    [ Svg.cx (toString (getX v))
                    , Svg.cy (toString (getY v))
                    , Svg.r "5"
                    , Svg.fill "transparent"
                    , Svg.strokeWidth "0"
                    , Svg.onClick
                        (updateId config.stateUpdated state (Just (toString id)))
                    , Svg.onMouseOver
                        (updateFocused config.stateUpdated state (Just id))
                    , Svg.onMouseOut
                        (updateFocused config.stateUpdated state Nothing)
                    ]
                    []
                , if id |> equals state.focused then
                    Svg.drawSelector v
                  else
                    Svg.g [] []
                ]
    in
        position store point
            |> Maybe.map draw


view : Config msg -> State -> PointStore -> Html msg
view config state store =
    let
        items =
            Dict.keys store
                |> List.map toString
                |> List.map
                    (\id ->
                        { value = id
                        , text = "point " ++ id
                        , enabled = True
                        }
                    )

        buttonAttributes =
            case
                ( Maybe.andThen (Result.toMaybe << String.toInt) state.id
                , state.x
                , state.y
                )
            of
                ( Just id, Just x, Just y ) ->
                    let
                        point =
                            relative id (vec2 x y)
                    in
                        [ Html.onClick (config.addPoint point)
                        , Html.disabled False
                        ]

                _ ->
                    [ Html.disabled True ]
    in
        Html.div []
            [ Html.div []
                [ Html.text "id:"
                , Dropdown.dropdown
                    { items = items
                    , emptyItem =
                        Just
                            { value = "-1"
                            , text = "select point"
                            , enabled = True
                            }
                    , onChange = updateId config.stateUpdated state
                    }
                    []
                    state.id
                , Html.button
                    [ Html.onClick (updateId config.stateUpdated state Nothing) ]
                    [ Html.text "clear" ]
                ]
            , Html.div []
                [ Html.text "x:"
                , inputX config state []
                , Html.button
                    [ Html.onClick (updateX config.stateUpdated state Nothing) ]
                    [ Html.text "clear" ]
                ]
            , Html.div []
                [ Html.text "y:"
                , inputY config state []
                , Html.button
                    [ Html.onClick (updateY config.stateUpdated state Nothing) ]
                    [ Html.text "clear" ]
                ]
            , Html.button
                buttonAttributes
                [ Html.text "add" ]
            ]


inputX : Config msg -> State -> List (Html.Attribute msg) -> Html msg
inputX config state attrs =
    let
        options =
            Input.Float.defaultOptions (updateX config.stateUpdated state)
    in
        Input.Float.input options attrs state.x


inputY : Config msg -> State -> List (Html.Attribute msg) -> Html msg
inputY config state attrs =
    let
        options =
            Input.Float.defaultOptions (updateY config.stateUpdated state)
    in
        Input.Float.input options attrs state.y



{- events -}


addPoint : Config msg -> State -> PointStore -> Maybe (Position -> msg)
addPoint config state store =
    let
        anchorId =
            state.id
                |> Maybe.andThen (String.toInt >> Result.toMaybe)

        anchorPosition =
            state.id
                |> Maybe.andThen (String.toInt >> Result.toMaybe)
                |> Maybe.andThen (flip Dict.get store)
                |> Maybe.andThen (position store)
    in
        case ( anchorId, anchorPosition ) of
            ( Just id, Just v ) ->
                Just <|
                    \pos ->
                        let
                            p =
                                svgToCanvas config.viewPort pos

                            x =
                                state.x
                                    |> Maybe.withDefault (toFloat p.x - getX v)

                            y =
                                state.y
                                    |> Maybe.withDefault (toFloat p.y - getY v)

                            w =
                                vec2 x y
                        in
                            config.addPoint (relative id w)

            _ ->
                Nothing


updateId : (State -> msg) -> State -> Maybe String -> msg
updateId callback state newId =
    callback
        { state
            | id = newId
            , focused = Nothing
        }


updateX : (State -> msg) -> State -> Maybe Float -> msg
updateX callback state newX =
    callback { state | x = newX }


updateY : (State -> msg) -> State -> Maybe Float -> msg
updateY callback state newY =
    callback { state | y = newY }


updateFocused : (State -> msg) -> State -> Maybe Id -> msg
updateFocused callback state newFocused =
    callback { state | focused = newFocused }
