{-# language Strict #-}
{-# language CPP #-}
{-# language PatternSynonyms #-}
{-# language OverloadedStrings #-}

module Graphics.Vulkan.Extensions.VK_EXT_shader_subgroup_ballot
  ( pattern VK_EXT_SHADER_SUBGROUP_BALLOT_SPEC_VERSION
  , pattern VK_EXT_SHADER_SUBGROUP_BALLOT_EXTENSION_NAME
  ) where

import Data.String
  ( IsString
  )





pattern VK_EXT_SHADER_SUBGROUP_BALLOT_SPEC_VERSION :: Integral a => a
pattern VK_EXT_SHADER_SUBGROUP_BALLOT_SPEC_VERSION = 1
pattern VK_EXT_SHADER_SUBGROUP_BALLOT_EXTENSION_NAME :: (Eq a ,IsString a) => a
pattern VK_EXT_SHADER_SUBGROUP_BALLOT_EXTENSION_NAME = "VK_EXT_shader_subgroup_ballot"