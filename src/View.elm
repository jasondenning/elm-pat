module View exposing (view)

import Dict exposing (Dict)
import Editor
    exposing
        ( Model
        , Msg(..)
        , Tool(..)
        , allTools
        , toolDescription
        , toolName
        )
import Expr exposing (..)
import Html exposing (Html)
import Html.Attributes as Html
import Html.Events as Events
import Math.Vector2 exposing (..)
import Styles.Colors exposing (..)
import Styles.Editor
    exposing
        ( Class(..)
        , class
        )
import Svg exposing (Svg)
import Tools.Absolute as Absolute
import Tools.Relative as Relative
import Tools.Select as Select
import Types
    exposing
        ( Id
        , Point
        , PointStore
        , ViewPort
        )
import View.Canvas as Canvas
import Views.PointTable as PointTable
import Views.ToolBox as ToolBox
import Views.VariableTable as VariableTable


{- main view -}


view : Model -> Html Msg
view model =
    Html.div
        [ class [ Main ] ]
        [ Html.div
            [ class [ Container, ContainerTopLeft ] ]
            [ ToolBox.view
            , viewToolInfo model.viewPort model.variables model.store model.tool
            ]
        , Html.div
            [ class [ Container, ContainerBottomLeft ] ]
            [ PointTable.view model.variables model.store ]
        , Html.div
            [ class [ Container, ContainerBottomRight ] ]
            [ VariableTable.view model.variables model.newName model.newValue ]
        , viewCanvas model
        ]



{- tool box -}


viewToolInfo : ViewPort -> Dict String E -> PointStore -> Tool -> Html Msg
viewToolInfo viewPort variables store tool =
    case tool of
        Absolute state ->
            Absolute.view variables (addAbsoluteConfig viewPort) state

        Relative state ->
            Relative.view (addRelativeConfig viewPort) state store

        Select _ ->
            Html.div [] []

        None ->
            Html.div [] []



{- canvas -}


viewCanvas : Model -> Html Msg
viewCanvas model =
    Canvas.view
        (drawTool model.viewPort model.variables model.store model.tool)
        model.viewPort
        model.store
        model.variables


drawTool : ViewPort -> Dict String E -> PointStore -> Tool -> Svg Msg
drawTool viewPort variables store tool =
    case tool of
        Absolute state ->
            Absolute.svg variables (addAbsoluteConfig viewPort) state

        Relative state ->
            Relative.svg (addRelativeConfig viewPort) state store variables

        Select state ->
            Select.svg (selectConfig viewPort) state store variables

        None ->
            Svg.g [] []



{- tool configurations -}


addAbsoluteConfig : ViewPort -> Absolute.Config Msg
addAbsoluteConfig viewPort =
    { addPoint = AddPoint
    , updatePoint = UpdatePoint
    , stateUpdated = UpdateTool << Absolute
    , viewPort = viewPort
    }


addRelativeConfig : ViewPort -> Relative.Config Msg
addRelativeConfig viewPort =
    { addPoint = AddPoint
    , updatePoint = UpdatePoint
    , stateUpdated = UpdateTool << Relative
    , viewPort = viewPort
    }


selectConfig : ViewPort -> Select.Config Msg
selectConfig viewPort =
    { selectPoint = SelectPoint
    , stateUpdated = UpdateTool << Select
    , viewPort = viewPort
    }
