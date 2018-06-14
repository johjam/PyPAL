module Experiment exposing (Model, Msg(..), init, view, update)

import Process
import Task
import Time
import Array exposing (Array)
import Http
import Html exposing (Html)
import Html.Attributes
import Html.Events
import Json.Encode
import Json.Decode
import LineChart
import LineChart.Junk as Junk
import LineChart.Area as Area
import LineChart.Axis as Axis
import LineChart.Junk as Junk
import LineChart.Dots as Dots
import LineChart.Grid as Grid
import LineChart.Dots as Dots
import LineChart.Line as Line
import LineChart.Colors as Colors
import LineChart.Events as Events
import LineChart.Legends as Legends
import LineChart.Container as Container
import LineChart.Interpolation as Interpolation
import LineChart.Axis.Intersection as Intersection
import Plugin
import Status exposing (Status, Progress, Point)
import Color


init : Model
init =
    Model Status.Unknown 1 [] ""


type alias Model =
    { status : Status
    , updates : Int
    , plugins : List Plugin.Model
    , comments : String
    }


type Msg
    = ChangeUpdates String
    | UpdatePlugins Json.Encode.Value
    | ChangeComments String
    | GetStatus
    | GetStatusResponse (Result Http.Error Status)
    | Post


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ChangeUpdates newValue ->
            ( { model | updates = Result.withDefault 1 <| String.toInt newValue }, Cmd.none )

        UpdatePlugins jsonValue ->
            case Json.Decode.decodeValue (Json.Decode.list Plugin.decode) jsonValue of
                Ok newData ->
                    let
                        newPlugins =
                            case List.head newData of
                                Nothing ->
                                    model.plugins

                                Just data ->
                                    ((if data.className == "None" then
                                        emptyPlugins
                                      else
                                        newData
                                     )
                                        ++ List.filter
                                            (.module_name >> ((/=) data.module_name))
                                            model.plugins
                                    )
                    in
                        ( { model | plugins = newPlugins }, Cmd.none )

                Err err ->
                    ( { model | status = Status.Error err }, Cmd.none )

        ChangeComments newValue ->
            ( { model | comments = newValue }, Cmd.none )

        GetStatus ->
            ( model, Http.send GetStatusResponse <| Http.get "status/" Status.decode )

        GetStatusResponse (Ok (Status.Running percent)) ->
            ( { model | status = Status.Running percent }, Task.perform (always GetStatus) <| Process.sleep <| 500 * Time.millisecond )

        GetStatusResponse (Ok status) ->
            ( { model | status = status }, Cmd.none )

        GetStatusResponse (Err err) ->
            ( { model | status = Status.Error (toString err) }, Cmd.none )

        Post ->
            let
                body =
                    Http.jsonBody (encode model)
            in
                ( model, Http.send GetStatusResponse <| Http.post "submit/" body Status.decode )


view : Model -> Html Msg
view model =
    Html.div [] <|
        case model.status of
            Status.Ready ->
                [ startExperimentView model, commentBox model ]

            Status.Running percentage ->
                [ liveplot model, statusView model ]

            otherwise ->
                [ statusView model ]


startExperimentView : Model -> Html Msg
startExperimentView model =
    Html.p []
        [ (case model.status of
            Status.Ready ->
                Html.button
                    [ Html.Attributes.id "start-button"
                    , Html.Events.onClick Post
                    ]
                    [ Html.text "Start" ]

            Status.Running progress ->
                Html.button
                    [ Html.Attributes.id "start-button-inactive" ]
                    [ Html.text <| progress.percentageString ]

            otherwise ->
                Html.button
                    [ Html.Attributes.id "start-button-inactive" ]
                    [ Html.text "Please wait" ]
          )
        , Html.input
            [ Html.Attributes.id "update-number"
            , Html.Attributes.value <| toString model.updates
            , Html.Attributes.type_ "number"
            , Html.Attributes.min "1"
            , Html.Events.onInput ChangeUpdates
            ]
            []
        , Html.span [ Html.Attributes.id "update-text" ]
            [ if model.updates == 1 then
                Html.text "update"
              else
                Html.text "updates"
            ]
        ]


statusView : Model -> Html msg
statusView model =
    Html.div [] <|
        case model.status of
            Status.Running progress ->
                [ Html.p [] [ Html.text <| "Experiment " ++ progress.percentageString ++ " complete" ]
                , Html.p [] [ Html.text <| "Stage: " ++ progress.currentStage ]
                , Html.p [] [ Html.text <| "Plugin: " ++ progress.currentPlugin ]
                ]

            otherwise ->
                [ Html.text <| toString model.status ]


commentBox : Model -> Html Msg
commentBox model =
    Html.p []
        [ Html.text "Comments:"
        , Html.br [] []
        , Html.textarea
            [ Html.Attributes.rows 3
            , Html.Attributes.cols 60
            , Html.Attributes.value model.comments
            , Html.Events.onInput ChangeComments
            ]
            []
        , Html.br [] []
        ]


liveplot : Model -> Html Msg
liveplot model =
    case model.status of
        Status.Running progress ->
            case List.head progress.livePlots of
                Nothing ->
                    Html.text ""

                Just pluginPlots ->
                    case List.head pluginPlots.plots of
                        Nothing ->
                            Html.text ""

                        Just plot ->
                            case List.length plot.series of
                                0 ->
                                    Html.text ""

                                1 ->
                                    let
                                        colors =
                                            [ Colors.blue ]
                                    in
                                        drawChart plot.title plot.xAxis plot.yAxis colors plot.series

                                2 ->
                                    let
                                        colors =
                                            [ Colors.blue, Colors.green ]
                                    in
                                        drawChart plot.title plot.xAxis plot.yAxis colors plot.series

                                3 ->
                                    let
                                        colors =
                                            [ Colors.blue, Colors.green, Colors.red ]
                                    in
                                        drawChart plot.title plot.xAxis plot.yAxis colors plot.series

                                otherwise ->
                                    Html.text ""

        otherwise ->
            Html.text ""


drawChart : String -> String -> String -> List Color.Color -> List Status.Series -> Html Msg
drawChart title xAxisTitle yAxisTitle colors allSeries =
    let
        allLines =
            List.map2 (\color series -> LineChart.line color Dots.circle series.name series.points) colors allSeries

        chartConfig =
            { y = Axis.default 400 yAxisTitle .y
            , x = Axis.default 700 xAxisTitle .x
            , container = Container.default title
            , interpolation = Interpolation.default
            , intersection = Intersection.default
            , legends = Legends.default
            , events = Events.default
            , junk = Junk.default
            , grid = Grid.default
            , area = Area.default
            , line = Line.default
            , dots = Dots.default
            }
    in
        Html.div []
            [ Html.p [ Html.Attributes.class "plotTitle" ] [ Html.text title ]
            , LineChart.viewCustom chartConfig allLines
            ]


errorPlotView : Html Msg
errorPlotView =
    Html.strong [] [ Html.text "There was an error!" ]


experimentShowData : Model -> List (Html Msg)
experimentShowData model =
    let
        makeHeading =
            \num name ->
                Html.th [ Html.Attributes.id ("device" ++ toString num) ] [ Html.text name ]

        makeModuleHeadings =
            \device num -> List.map (makeHeading num) device.dataRegister

        allHeadings =
            List.concat <|
                List.map2 makeModuleHeadings (List.sortBy .priority model.plugins) <|
                    List.map (\x -> x % 3 + 1) <|
                        List.range 1 (List.length model.plugins)

        numHeadings =
            List.length allHeadings
    in
        [ Html.h2 [] [ Html.text "NumPy data array layout" ]
        , Html.table [ Html.Attributes.id "data-table" ] <|
            [ Html.tr []
                (Html.th [] []
                    :: Html.th [ Html.Attributes.id "device0" ] [ Html.text "time" ]
                    :: allHeadings
                )
            ]
                ++ (case model.updates of
                        1 ->
                            [ Html.tr []
                                (Html.td [] [ Html.text "0" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            ]

                        2 ->
                            [ Html.tr []
                                (Html.td [] [ Html.text "0" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            , Html.tr []
                                (Html.td [] [ Html.text "1" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            ]

                        3 ->
                            [ Html.tr []
                                (Html.td [] [ Html.text "0" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            , Html.tr []
                                (Html.td [] [ Html.text "1" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            , Html.tr []
                                (Html.td [] [ Html.text "2" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            ]

                        4 ->
                            [ Html.tr []
                                (Html.td [] [ Html.text "0" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            , Html.tr []
                                (Html.td [] [ Html.text "1" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            , Html.tr []
                                (Html.td [] [ Html.text "2" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            , Html.tr []
                                (Html.td [] [ Html.text "3" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            ]

                        5 ->
                            [ Html.tr []
                                (Html.td [] [ Html.text "0" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            , Html.tr []
                                (Html.td [] [ Html.text "1" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            , Html.tr []
                                (Html.td [] [ Html.text "2" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            , Html.tr []
                                (Html.td [] [ Html.text "3" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            , Html.tr []
                                (Html.td [] [ Html.text "4" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            ]

                        otherwise ->
                            [ Html.tr []
                                (Html.td [] [ Html.text "0" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            , Html.tr []
                                (Html.td [] [ Html.text "1" ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            , Html.tr [ Html.Attributes.class "skip-row" ]
                                (Html.td [] [ Html.text "..." ]
                                    :: List.repeat (numHeadings + 1)
                                        (Html.td []
                                            [ Html.text "..." ]
                                        )
                                )
                            , Html.tr []
                                (Html.td [] [ Html.text (toString (model.updates - 2)) ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            , Html.tr []
                                (Html.td [] [ Html.text (toString (model.updates - 1)) ]
                                    :: List.repeat (numHeadings + 1) (Html.td [] [])
                                )
                            ]
                   )
        ]


encode : Model -> Json.Encode.Value
encode model =
    Json.Encode.object
        [ ( "status", Json.Encode.string <| toString model.status )
        , ( "updates", Json.Encode.int model.updates )
        , ( "plugins", Json.Encode.list <| List.map Plugin.encode model.plugins )
        , ( "comments", Json.Encode.string model.comments )
        ]


decode : Json.Decode.Decoder Model
decode =
    Json.Decode.map4
        Model
        (Json.Decode.field "status" Status.decode)
        (Json.Decode.field "updates" Json.Decode.int)
        (Json.Decode.field "plugins" (Json.Decode.list Plugin.decode))
        (Json.Decode.field "comments" Json.Decode.string)


emptyPlugins : List Plugin.Model
emptyPlugins =
    []
