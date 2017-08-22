port module H5Output exposing (main)

import Html exposing (Html)
import Html.Events
import Html.Attributes
import Json.Encode
import ModuleHelpers


type alias Model =
    { className : String
    , active : Bool
    , traceField : String
    , xField : String
    , yField : String
    , thetaField : String
    , extra1Name : String
    , extra1Value : String
    , extra2Name : String
    , extra2Value : String
    }


type Msg
    = ToggleActive
    | ChangeTraceField String
    | ChangeXField String
    | ChangeYField String
    | ChangeThetaField String
    | ChangeExtra1Name String
    | ChangeExtra1Value String
    | ChangeExtra2Name String
    | ChangeExtra2Value String
    | SendJson


port jsonData : Json.Encode.Value -> Cmd msg


main : Program Never Model Msg
main =
    Html.program
        { init = ( defaultModel, Cmd.none )
        , view = \model -> Html.div [] (viewModel model)
        , update = updateModel
        , subscriptions = \_ -> Sub.none
        }


defaultModel : Model
defaultModel =
    { className = "None"
    , active = False
    , traceField = ""
    , xField = ""
    , yField = ""
    , thetaField = ""
    , extra1Name = ""
    , extra1Value = ""
    , extra2Name = ""
    , extra2Value = ""
    }


viewModel : Model -> List (Html Msg)
viewModel model =
    ModuleHelpers.title "PAL H5 output" model.active ToggleActive
        ++ if model.active then
            [ ModuleHelpers.stringField "trace field" model.traceField ChangeTraceField
            , ModuleHelpers.stringField "x-position field" model.xField ChangeXField
            , ModuleHelpers.stringField "y-position field" model.yField ChangeYField
            , ModuleHelpers.stringField "theta-position field" model.thetaField ChangeThetaField
            , Html.h4 [] [ Html.text "Add arbitrary data to the H5 headers (optional)" ]
            , ModuleHelpers.stringField "header key 1" model.extra1Name ChangeExtra1Name
            , ModuleHelpers.stringField "header value 1" model.extra1Value ChangeExtra1Value
            , ModuleHelpers.stringField "header key 2" model.extra2Name ChangeExtra2Name
            , ModuleHelpers.stringField "header value 2" model.extra2Value ChangeExtra2Value
            ]
           else
            [ ModuleHelpers.empty ]


updateModel : Msg -> Model -> ( Model, Cmd Msg )
updateModel msg model =
    case msg of
        ToggleActive ->
            if model.active then
                updateModel SendJson
                    { model
                        | className = "None"
                        , active = False
                    }
            else
                updateModel SendJson
                    { model
                        | className = "H5Output"
                        , active = True
                    }

        ChangeTraceField newField ->
            updateModel SendJson { model | traceField = newField }

        ChangeXField newField ->
            updateModel SendJson { model | xField = newField }

        ChangeYField newField ->
            updateModel SendJson { model | yField = newField }

        ChangeThetaField newField ->
            updateModel SendJson { model | thetaField = newField }

        ChangeExtra1Name newKey ->
            updateModel SendJson { model | extra1Name = newKey }

        ChangeExtra1Value newValue ->
            updateModel SendJson { model | extra1Value = newValue }

        ChangeExtra2Name newKey ->
            updateModel SendJson { model | extra2Name = newKey }

        ChangeExtra2Value newValue ->
            updateModel SendJson { model | extra2Value = newValue }

        SendJson ->
            ( model
            , jsonData
                (Json.Encode.list
                    [ Json.Encode.object
                        [ ( "module_name", Json.Encode.string "h5_output" )
                        , ( "class_name", Json.Encode.string model.className )
                        , ( "priority", Json.Encode.int 9999 )
                        , ( "data_register", Json.Encode.list (List.map Json.Encode.string []) )
                        , ( "config"
                          , Json.Encode.object
                                [ ( "trace_field", Json.Encode.string model.traceField )
                                , ( "x_position_field", Json.Encode.string model.xField )
                                , ( "y_position_field", Json.Encode.string model.yField )
                                , ( "theta_position_field", Json.Encode.string model.thetaField )
                                , ( "header_extra1_name", Json.Encode.string model.extra1Name )
                                , ( "header_extra1_val", Json.Encode.string model.extra1Value )
                                , ( "header_extra2_name", Json.Encode.string model.extra2Name )
                                , ( "header_extra2_val", Json.Encode.string model.extra2Value )
                                ]
                          )
                        ]
                    ]
                )
            )
