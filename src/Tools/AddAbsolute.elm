module Tools.AddAbsolute
    exposing
        ( State
        , Config
        , init
        , fromVec
        , svg
        , view
        )

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
        { x : Maybe Float
        , y : Maybe Float
        }


init : State
init =
    { x = Nothing
    , y = Nothing
    , mouse = Nothing
    }


fromVec : Vec2 -> State
fromVec v =
    { init
        | x = Just (getX v)
        , y = Just (getY v)
    }



{- config -}


type alias Config msg =
    { addPoint : Point -> msg
    , stateUpdated : State -> msg
    , viewPort : ViewPort
    }



{- canvas -}


svg : Config msg -> State -> Svg msg
svg config state =
    Svg.g []
        [ case state.mouse of
            Just position ->
                drawCursor config state position

            Nothing ->
                Svg.g [] []
        , drawLines config state
        , drawNewPoint config state
        , eventRect config state
        ]


drawCursor : Config msg -> State -> Position -> Svg msg
drawCursor config state p =
    case ( state.x, state.y ) of
        ( Just x, Just y ) ->
            Svg.g [] []

        ( Just x, Nothing ) ->
            Svg.g []
                [ Svg.drawPoint (vec2 x (toFloat p.y))
                , Svg.drawSelector (vec2 x (toFloat p.y))
                ]

        ( Nothing, Just y ) ->
            Svg.g []
                [ Svg.drawPoint (vec2 (toFloat p.x) y)
                , Svg.drawSelector (vec2 (toFloat p.x) y)
                ]

        ( Nothing, Nothing ) ->
            Svg.g []
                [ Svg.drawPoint (vec p.x p.y)
                , Svg.drawSelector (vec p.x p.y)
                ]


drawLines : Config msg -> State -> Svg msg
drawLines config state =
    case ( state.x, state.y ) of
        ( Just x, Just y ) ->
            Svg.g [] []

        ( Just x, Nothing ) ->
            Svg.g []
                [ Svg.drawVerticalLine x ]

        ( Nothing, Just y ) ->
            Svg.g []
                [ Svg.drawHorizontalLine y ]

        ( Nothing, Nothing ) ->
            Svg.g [] []


drawNewPoint : Config msg -> State -> Svg msg
drawNewPoint config state =
    case ( state.x, state.y ) of
        ( Just x, Just y ) ->
            Svg.g []
                [ Svg.drawPoint (vec2 x y)
                , Svg.drawSelector (vec2 x y)
                ]

        _ ->
            Svg.g [] []


eventRect : Config msg -> State -> Svg msg
eventRect config state =
    Svg.rect
        [ Svg.x (toString config.viewPort.x)
        , Svg.y (toString config.viewPort.y)
        , Svg.width (toString config.viewPort.width)
        , Svg.height (toString config.viewPort.height)
        , Svg.fill "transparent"
        , Svg.strokeWidth "0"
        , Events.onClick (addPoint config state)
        , Events.onMove
            (updateMouse config.stateUpdated state config.viewPort << Just)
        , Svg.onMouseOut
            (updateMouse config.stateUpdated state config.viewPort Nothing)
        ]
        []



{- view -}


view : Config msg -> State -> Html msg
view config state =
    let
        buttonAttributes =
            case ( state.x, state.y ) of
                ( Just x, Just y ) ->
                    let
                        point =
                            absolute (vec2 x y)
                    in
                        [ Html.onClick (config.addPoint point)
                        , Html.disabled False
                        ]

                _ ->
                    [ Html.disabled True ]
    in
        Html.div []
            [ Html.div []
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


addPoint : Config msg -> State -> Position -> msg
addPoint config state position =
    let
        p =
            svgToCanvas config.viewPort position
    in
        case ( state.x, state.y ) of
            ( Just x, Just y ) ->
                config.addPoint (absolute (vec2 x y))

            ( Just x, Nothing ) ->
                config.addPoint (absolute (vec2 x (toFloat p.y)))

            ( Nothing, Just y ) ->
                config.addPoint (absolute (vec2 (toFloat p.x) y))

            ( Nothing, Nothing ) ->
                config.addPoint (absolute (vec p.x p.y))


updateX : (State -> msg) -> State -> Maybe Float -> msg
updateX callback state newX =
    callback { state | x = newX }


updateY : (State -> msg) -> State -> Maybe Float -> msg
updateY callback state newY =
    callback { state | y = newY }
