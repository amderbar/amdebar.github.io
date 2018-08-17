module Main where

import Prelude
import Mkpasswd                  (mkpasswd, defaultPolicy)
--import Data.Generic              (class Generic, gshow)
import Data.Maybe                (Maybe(..), fromMaybe, isJust)
import Data.Either               (Either(..), note)
import Data.Int                  (fromString)
import Data.String.CodePoints    (length)
import Data.Tuple                (Tuple(..))
import Effect                    (Effect)
import Effect.Aff                (Aff)
import Halogen                 as H
import Halogen.Aff             as HA
import Halogen.HTML            as HH
import Halogen.HTML.Events     as HE
import Halogen.HTML.Properties as HP
import Halogen.VDom.Driver       (runUI)

type State =
    { policy :: { length    :: Int
                , degit     :: Tuple Boolean Int
                , uppercase :: Tuple Boolean Int
                , lowercase :: Tuple Boolean Int
                , symbol    :: Tuple Boolean Int
                }
    , passwd :: String
    , errMsg :: String
    }

data FieldType
    = PasswdLength
    | DegitsNum
    | UppercaseNum
    | LowercaseNum
    | SymbolNum

----Package generics does not exist in package set
--derive instance genericFieldType :: Generic FieldType
instance showFieldType :: Show FieldType where
--    show = gShow
    show PasswdLength = "PasswdLength"
    show DegitsNum    = "DegitsNum"
    show UppercaseNum = "UppercaseNum"
    show LowercaseNum = "LowercaseNum"
    show SymbolNum    = "SymbolNum"

data Query a = Regenerate a
             | UpdatePolicy FieldType String a
             | UpdateChecked FieldType Boolean a

id :: forall a. a -> a
id v = v

classes :: forall a b. Array String -> HH.IProp ( "class" :: String | b) a
classes = HP.classes <<< map HH.ClassName

style :: forall a b. String -> HH.IProp b a
style = HP.attr $ HH.AttrName "style"

headerNav :: forall a b. HH.HTML a b
headerNav =
    HH.nav
        [ classes [ "border", "flex-none", "flex", "justify-center" ] ]
        [ HH.a
            [ classes [ "flex-auto", "border", "p1", "center" ] ]
            [ HH.text "つくる" ]
        , HH.a
            [ classes [ "flex-auto", "border", "p1", "center" ] ]
            [ HH.text "しまう" ]
        ]

eval :: Query ~> H.ComponentDSL State Query Void Aff
eval (Regenerate next) = do
    s <- H.get
    newPasswd <- H.liftEffect $
        mkpasswd { length    : s.policy.length
                 , degit     : toMaybe s.policy.degit
                 , uppercase : toMaybe s.policy.uppercase
                 , lowercase : toMaybe s.policy.lowercase
                 , symbol    : toMaybe s.policy.symbol
                 }
    case newPasswd of
         Right pass -> H.modify_ (_ { errMsg = "", passwd = pass })
         Left  err  -> H.modify_ (_ { errMsg = show err  })
    pure next
    where
          toMaybe (Tuple flg num) = if flg then Just num else Nothing

eval (UpdatePolicy feildType value next) =
    let newValue = note (show feildType <> " should be a Number") $ fromString value
     in do
        state <- H.get
        case newValue of
             Right vli -> modifyPolicy feildType state vli
             Left  err -> H.modify_ (_ { errMsg = err })
        pure next
        where
              updateTuple (Tuple b _) n = Tuple b n
              modifyPolicy f s v = do
                  let p = s.policy
                  let newPolicy =
                        case f of
                           PasswdLength  -> p { length    = v }
                           DegitsNum     -> p { degit     = updateTuple p.degit v }
                           UppercaseNum  -> p { uppercase = updateTuple p.uppercase v }
                           LowercaseNum  -> p { lowercase = updateTuple p.lowercase v }
                           SymbolNum     -> p { symbol    = updateTuple p.symbol v }
                  H.modify_ (_ { errMsg = "", policy = newPolicy })

eval (UpdateChecked feildType flg next) = do
    state <- H.get
    modifyPolicy feildType state flg
    pure next
    where
          updateTuple (Tuple _ i) f = Tuple f i
          modifyPolicy f s v = do
             let p = s.policy
             let newPolicy =
                     case f of
                          PasswdLength  -> p
                          DegitsNum     -> p { degit     = updateTuple p.degit v }
                          UppercaseNum  -> p { uppercase = updateTuple p.uppercase v }
                          LowercaseNum  -> p { lowercase = updateTuple p.lowercase v }
                          SymbolNum     -> p { symbol    = updateTuple p.symbol v }
             H.modify_ (_ { errMsg = "", policy = newPolicy })

ui :: H.Component HH.HTML Query Unit Void Aff
ui =
  H.component
    { initialState: const initialState
    , render
    , eval
    , receiver : const Nothing
    }
    where
          initialState :: State
          initialState =
              let d = defaultPolicy
               in
                  { policy : { length    : d.length
                             , degit     : tuple d.degit
                             , uppercase : tuple d.uppercase
                             , lowercase : tuple d.lowercase
                             , symbol    : tuple d.symbol
                             }
                  , passwd : ""
                  , errMsg : ""
                  }
          tuple m = Tuple (isJust m) (fromMaybe 0 m)

          --render :: forall m. State -> H.ComponentHTML Query () m
          --render :: forall m. State -> H.ComponentHTML (Query Unit)
          render state =
              HH.main
                [ style "height: 100%"
                , classes [ "flex" , "flex-column" ]
                ]
                --[ headerNav
                [ HH.h1 [ classes [ "center" ] ] [ HH.text "Mkpasswd" ]
                , errorView state.errMsg
                , lengthFormRow PasswdLength "ながさ：" state.policy.length
                , policyFormRow DegitsNum    "すうじ：" state.policy.degit
                , policyFormRow UppercaseNum "英大字：" state.policy.uppercase
                , policyFormRow LowercaseNum "英小字：" state.policy.lowercase
                , policyFormRow SymbolNum    "きごう：" state.policy.symbol
                , resultView state.passwd
                , HH.button
                    [ classes [ "self-center", "p1" ]
                    , HE.onClick (HE.input_ Regenerate)
                    ]
                    [ HH.text "Generate new Password" ]
                    ]
          lengthFormRow feildType labelTxt currVal =
              let inpIdStr = show feildType
               in
                  HH.div
                     [ classes [ "flex-none", "clearfix" ] ]
                     [ HH.label
                          [ HP.for inpIdStr
                          , classes [ "pr1", "col", "col-4", "right-align", "align-baseline", "label" ]
                          ]
                          [ HH.text labelTxt ]
                     , HH.input
                          [ HP.type_ HP.InputNumber
                          , HP.id_ inpIdStr
                          , classes [ "col", "col-3", "input" ]
                          , HP.value $ show currVal
                          , HE.onValueInput $ HE.input (UpdatePolicy feildType)
                          ]
                     ]
          policyFormRow feildType labelTxt (Tuple currChk currVal) =
              let inpIdStr = show feildType
               in
                  HH.div
                     [ classes [ "flex-none", "clearfix" ] ]
                     [ HH.label
                          [ HP.for inpIdStr
                          , classes [ "pr1", "col", "col-4", "right-align", "align-baseline", "label" ]
                          ]
                          [ HH.text labelTxt ]
                     , HH.input
                          [ HP.type_ HP.InputNumber
                          , HP.id_ inpIdStr
                          , classes [ "col", "col-3", "input" ]
                          , HP.disabled $ not currChk
                          , HP.value $ show currVal
                          , HE.onValueInput $ HE.input (UpdatePolicy feildType)
                          ]
                     , HH.label
                          [ classes [ "pl1", "col", "col-4", "left-align", "align-baseline", "label" ]
                          ]
                          [ HH.input
                              [ HP.type_ HP.InputCheckbox
                              , HP.checked currChk
                              , HE.onChecked $ HE.input (UpdateChecked feildType)
                              ]
                          , HH.text "含める"
                          ]
                     ]
          resultView value =
              if length value > 0
                  then HH.p [ classes [ "h3", "center", "border", "rounded" ] ]
                            [ HH.text value ]
                  else HH.text value
          errorView  error =
              if length error > 0
                  then HH.p [ classes [ "h3" , "center" , "border" , "border-red" ] ]
                            [ HH.text error ]
                  else HH.text error


main :: Effect Unit
main = HA.runHalogenAff do
  body <- HA.awaitBody
  runUI ui unit body
