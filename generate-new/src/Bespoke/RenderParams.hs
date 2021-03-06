module Bespoke.RenderParams
  ( renderParams
  ) where

import           Data.Char                      ( isLower )
import qualified Data.HashSet                  as Set
import qualified Data.List                     as List
import qualified Data.Text                     as T
import           Data.Text.Extra               as T
                                                ( (<+>)
                                                , lowerCaseFirst
                                                , upperCaseFirst
                                                )
import           Data.Text.Prettyprint.Doc      ( pretty )
import           Data.Tuple.Extra               ( curry3 )
import qualified Data.Vector                   as V
import           Language.Haskell.TH            ( nameBase )
import           Relude                  hiding ( Handle
                                                , Type
                                                , uncons
                                                )
import           Text.Casing

import           Foreign.C.Types
import           Foreign.Ptr

import           CType
import           Haskell
import           Render.Element
import           Render.Stmts                   ( useViaName )
import           Render.Stmts.Poke              ( CmdsDoc(..) )
import           Render.Type.Preserve
import           Spec.Parse

renderParams :: V.Vector Handle -> RenderParams
renderParams handles = r
 where
  dispatchableHandleNames = Set.fromList
    [ hName | Handle {..} <- toList handles, hDispatchable == Dispatchable ]
  r = RenderParams
    { mkTyName                    = TyConName . upperCaseFirst . dropVk
    , mkConName                   = \parent ->
                                      ConName
                                        . (case parent of
                                            "VkPerformanceCounterResultKHR" -> (<> "Counter")
                                            "VkDeviceOrHostAddressConstKHR" -> (<> "Const")
                                            _ -> id
                                          )
                                        . upperCaseFirst
                                        . dropVk
    , mkMemberName = TermName . lowerCaseFirst . dropPointer . unCName
    , mkFunName                   = TermName . lowerCaseFirst . dropVk
    , mkParamName                 = TermName . dropPointer . unCName
    , mkPatternName               = ConName . upperCaseFirst . dropVk
    , mkFuncPointerName           = TyConName . T.tail . unCName
    , mkFuncPointerMemberName = TermName . ("p" <>) . upperCaseFirst . unCName
    , mkEmptyDataName             = TyConName . (<> "_T") . dropVk
    , mkDispatchableHandlePtrName = TermName
                                    . (<> "Handle")
                                    . lowerCaseFirst
                                    . dropVk
    , alwaysQualifiedNames        = mempty
    , mkIdiomaticType             =
      (`List.lookup` (  [ wrappedIdiomaticType ''Float  ''CFloat  'CFloat
                        , wrappedIdiomaticType ''Int32  ''CInt    'CInt
                        , wrappedIdiomaticType ''Double ''CDouble 'CDouble
                        , wrappedIdiomaticType ''Word64 ''CSize   'CSize
                        ]
                     <> [ ( ConT (typeName $ mkTyName r "VkBool32")
                          , IdiomaticType
                            (ConT ''Bool)
                            (do
                              tellImport (TermName "boolToBool32")
                              pure "boolToBool32"
                            )
                            (do
                              tellImport (TermName "bool32ToBool")
                              pure $ PureFunction "bool32ToBool"
                            )
                          )
                        ]
                     <> [ ( ConT ''Ptr
                            :@ ConT (typeName $ mkEmptyDataName r name)
                          , IdiomaticType
                            (ConT (typeName $ mkTyName r name))
                            (do
                              let h = mkDispatchableHandlePtrName r name
                              tellImportWithAll (mkTyName r name)
                              pure (pretty h)
                            )
                            (do
                              let c = mkConName r name name
                              tellImportWith (mkTyName r name) c
                              case name of
                                "VkInstance" -> do
                                  tellImport (TermName "initInstanceCmds")
                                  pure
                                    .   IOFunction
                                    $   "(\\h ->"
                                    <+> pretty c
                                    <+> "h <$> initInstanceCmds h)"
                                "VkDevice" -> do
                                  tellImport (TermName "initDeviceCmds")
                                  CmdsDoc cmds <- useViaName "cmds"
                                  pure
                                    .   IOFunction
                                    $   "(\\h ->"
                                    <+> pretty c
                                    <+> "h <$> initDeviceCmds"
                                    <+> cmds
                                    <+> "h)"
                                _ -> do
                                  CmdsDoc cmds <- useViaName "cmds"
                                  pure
                                    .   PureFunction
                                    $   "(\\h ->"
                                    <+> pretty c
                                    <+> "h"
                                    <+> cmds
                                    <+> ")"
                            )
                          )
                        | name <- toList dispatchableHandleNames
                        ]
                     )
      )
    , mkHsTypeOverride            = \_ preserve t -> pure <$> case preserve of
      DoNotPreserve -> Nothing
      _             -> case t of
        TypeName n | Set.member n dispatchableHandleNames ->
          Just $ ConT ''Ptr :@ ConT (typeName (mkEmptyDataName r n))
        _ -> Nothing
    , unionDiscriminators         = V.fromList
      [ UnionDiscriminator
        "VkPipelineExecutableStatisticValueKHR"
        "VkPipelineExecutableStatisticFormatKHR"
        "format"
        [ ("VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_BOOL32_KHR" , "b32")
        , ("VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_INT64_KHR"  , "i64")
        , ("VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_UINT64_KHR" , "u64")
        , ("VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_FLOAT64_KHR", "f64")
        ]
      , UnionDiscriminator
        "VkPerformanceValueDataINTEL"
        "VkPerformanceValueTypeINTEL"
        "type"
        [ ("VK_PERFORMANCE_VALUE_TYPE_UINT32_INTEL", "value32")
        , ("VK_PERFORMANCE_VALUE_TYPE_UINT64_INTEL", "value64")
        , ("VK_PERFORMANCE_VALUE_TYPE_FLOAT_INTEL" , "valueFloat")
        , ("VK_PERFORMANCE_VALUE_TYPE_BOOL_INTEL"  , "valueBool")
        , ("VK_PERFORMANCE_VALUE_TYPE_STRING_INTEL", "valueString")
        ]
      , UnionDiscriminator
        "VkAccelerationStructureGeometryDataKHR"
        "VkGeometryTypeKHR"
        "geometryType"
        [ ("VK_GEOMETRY_TYPE_TRIANGLES_KHR", "triangles")
        , ("VK_GEOMETRY_TYPE_AABBS_KHR"    , "aabbs")
        , ("VK_GEOMETRY_TYPE_INSTANCES_KHR", "instances")
        ]
      ]
    , successCodeType             = TypeName "VkResult"
    , isSuccessCodeReturned       = (/= "VK_SUCCESS")
    , firstSuccessCode            = "VK_SUCCESS"
    , exceptionTypeName           = TyConName "VulkanException"
    , complexMemberLengthFunction = curry3 $ \case
      ("pAllocateInfo", "descriptorSetCount", sibling) -> Just $ do
        tellQualImport 'V.length
        tellImportWithAll (mkTyName r "VkDescriptorSetAllocateInfo")
        pure
          $   "fromIntegral . Data.Vector.length ."
          <+> pretty (mkMemberName r "pSetLayouts")
          <+> "$"
          <+> sibling
      _ -> Nothing
    , isExternalName              = const Nothing
    , externalDocHTML             =
      Just
        "https://www.khronos.org/registry/vulkan/specs/1.2-extensions/html/vkspec.html"
    , objectTypePattern           = pure
                                    . mkPatternName r
                                    . CName
                                    . ("VK_OBJECT_TYPE_" <>)
                                    . T.pack
                                    . toScreamingSnake
                                    . fromHumps
                                    . T.unpack
                                    . dropVk
    }

wrappedIdiomaticType
  :: Name
  -- ^ Wrapped type
  -> Name
  -- ^ Wrapping type constructor
  -> Name
  -- ^ Wrapping constructor
  -> (Type, IdiomaticType)
  -- ^ (Wrapping type (CFloat), idiomaticType)
wrappedIdiomaticType t w c =
  ( ConT w
  , IdiomaticType
    (ConT t)
    (do
      tellImportWith w c
      pure (pretty (nameBase c))
    )
    (do
      tellImportWith w c
      pure . Constructor . pretty . nameBase $ c
    )
  )

dropVk :: CName -> Text
dropVk (CName t) = if "vk" `T.isPrefixOf` T.toLower t
  then T.dropWhile (== '_') . T.drop 2 $ t
  else t

dropPointer :: Text -> Text
dropPointer =
  lowerCaseFirst
    . uncurry (<>)
    . first (\p -> if T.all (== 'p') p then "" else p)
    . T.span isLower

