module SGXTools.Types where

import           SGXTools.Utils
import           Text.Printf
import           Data.Foldable (foldr')
import qualified Data.ByteString.Lazy as L
import qualified Data.ByteString      as B
import           Data.Word (Word64, Word32, Word16, Word8)
import           Data.Bits ((.&.), (.|.),
                            shiftL, shiftR,
                            Bits(..))


data SECS = SECS {
  secsSize                    :: Word64        -- Size of enclave in bytes; must be power of 2
  , secsBaseAddr              :: Word64        -- Enclave Base Linear Address must be naturally aligned to size
  , secsSSAFrameSize          :: Word32        -- Size of one SSA frame in pages (including XSAVE, pad, GPR, and conditionally MISC).
  , secsMiscSelect            :: MiscSelect    -- See MiscSecelct data type
  , secsReserved_byte24_47    :: L.ByteString  -- Reserved bytes. Set to zero
  , secsAttr                  :: Attributes    -- See Attributes data type
  , secsMrEnclave             :: L.ByteString  -- 256-bit SHA256 hash
  , secsReserved_byte96_127   :: L.ByteString  -- Reserved bytes. Set to zero
  , secsMrSigner              :: L.ByteString  -- 256-bit SHA256 hash of signer public key *after* enclave sig was verified
  , secsReserved_byte160_255  :: L.ByteString  -- Reserved bytes. Set to zero
  , secsISVProdId             :: Word16        -- Product ID of enclave
  , secsISVSVN                :: Word16        -- Security version number (SVN) of the enclave
  , secsReserved_byte260_4095 :: L.ByteString  -- 3836 bytes of wasted space
  }

data MiscSelect = MiscSelect {
  miscExInfo             :: Bool   -- Report information about page fault and general protection exception that occurred inside an enclave
  , miscReserved_bit1_32 :: Word32 -- Wasted space
  } deriving (Eq, Show)

data Attributes = Attributes {
  attrInit                :: Bool -- if the enclave has been initialized by EINIT
  , attrDebug             :: Bool -- If 1, the enclave permit debugger to read and write enclave data
  , attrMode64Bit         :: Bool -- Enclave runs in 64-bit mode
  , attrReserved_bit3     :: Bool -- Must be zero
  , attrProvisionKey      :: Bool -- Provisioning Key is available from EGETKEY
  , attrEinitTokenKey     :: Bool -- EINIT token key is available from EGETKEY
  , attrReserved_bit6_63  :: L.ByteString -- Reserved. Set to zero.
  , attrXFRM              :: XFRM -- See XFRM data type
  }deriving(Eq, Show)

data XFRMFlags = X87      -- 0x1
               | SSE      -- 0x2
               | AVX      -- 0x4
               | AVX512   -- 0xE0
               | MPX      -- 0x18
               | XFRMFlagUnknown Word64
               deriving(Show)

data XFRM = XFRM {
  xfrmEnabled  :: Bool
  , xfrmXCR0  :: Word64    -- Valid value of XCR0
  , xfrmHasXSave :: Bool -- Does the CPU has XSAVE instruction
  } deriving(Eq, Show)

data PageInfo = PageInfo {
  pgEnclaveLinAddr  :: Word64        -- Enclave linear address.
  , pgSourceAddr    :: Word64        -- Effective address of the page where contents are located.
  , pgSecInfo       :: Word64        -- Effective address of the SECINFO or PCMD
  , pgSecs          :: Word64        -- Effective address of EPC slot that currently contains the SECS
  }

newtype SecInfo = SecInfo {
  secInfoFlags :: [SecInfoFlags]
  } deriving (Show)


data PageType = PT_SECS
              | PT_TCS
              | PT_REG
              | PT_VA
              | PT_TRIM
              deriving (Show, Eq)

data TCS_POLICY = TCS_POLICY_BIND
                | TCS_POLICY_UNBIND
                deriving (Show, Eq)

instance Enum TCS_POLICY where
  toEnum 0 = TCS_POLICY_BIND
  toEnum 1 = TCS_POLICY_UNBIND
  toEnum _ = undefined

  fromEnum TCS_POLICY_BIND   = 0
  fromEnum TCS_POLICY_UNBIND = 1

instance Enum PageType where
  toEnum 0 = PT_SECS
  toEnum 1 = PT_TCS
  toEnum 2 = PT_REG
  toEnum 3 = PT_VA
  toEnum 4 = PT_TRIM
  toEnum _ = undefined

  fromEnum PT_SECS = 0
  fromEnum PT_TCS  = 1
  fromEnum PT_REG  = 2
  fromEnum PT_VA   = 3
  fromEnum PT_TRIM = 4

data PCMD = PCMD {
  pcmdSecInfo               :: SecInfo
  , pcmdEnclaveId           :: Word64
  , pcmdReserved_byte72_111 :: L.ByteString
  , pcmdMac                 :: L.ByteString   -- 16-Bytes
  }

data SigStruct = SigStruct{
  ssHeader1                :: SigStructHeader      -- 12 bytes. Signed
  , ssIsDebug              :: Word32               -- 4 bytes. Signed
  , ssVendor               :: SigStructVendor      -- 4  bytes. Signed
  , ssBuildDate            :: SigStructDate        -- 4  bytes. Signed
  , ssHeader2              :: SigStructHeader      -- 16 bytes. Signed
  , ssSwDefined            :: Word32               -- 4  bytes. Signed
  , ssReserved_byte44_127  :: L.ByteString         -- 84 bytes of zero. Signed
  , ssModulus              :: Integer              -- 384 bytes. Not signed
  , ssExponent             :: Word32               -- 4  bytes. Not signed
  , ssSignature            :: Integer              -- 384 bytes. Not signed
  , ssMiscSelect           :: MiscSelect           -- 4  bytes. Signed
  , ssMiscMask             :: MiscSelect           -- 4  bytes. Signed
  , ssReserved_byte908_927 :: L.ByteString         -- 20 bytes of zero. Signed
  , ssAttributes           :: Attributes           -- 16 bytes. Signed
  , ssAttributesMask       :: Attributes           -- 16 bytes. Signed
  , ssEnclaveHash          :: L.ByteString         -- 32 bytes of SHA256 of enclave. Signed
  , ssReserved_byte992_1023 :: L.ByteString        -- 32 bytes of zero. Signed
  , ssIsvProdId           :: Word16                -- 2  bytes. Signed
  , ssIsvSvn              :: Word16                -- 2  bytes. Signed
  , ssReserved_byte1028_1039 :: L.ByteString       -- 12 bytes of zero. Not signed
  , ssQ1                     :: Integer            -- 384 bytes of Q1
  , ssQ2                     :: Integer            -- 384 bytes of Q2
  }deriving(Show)


type CSS = SigStruct

data EInitToken = EInitToken {
  eitDebug                   :: Bool               -- 4 Bytes. MACed
  , eitReserved_byte4_47     :: L.ByteString       -- 44 Bytes of Zero. MACed
  , eitAttributes            :: Attributes         -- 16 Bytes. MACed
  , eitMrEnclave             :: L.ByteString       -- 32 Bytes. MACed
  , eitReserved_byte96_127   :: L.ByteString       -- 32 Bytes of Zero. MACed
  , eitMrSigner              :: L.ByteString       -- 32 Bytes. MACed
  , eitReserved_byte160_191  :: L.ByteString       -- 32 Bytes. MACed.
  , eitCpuSvnLe              :: CPUSVN             -- 16 Bytes. Not MACed
  , eitIsvProdIdLe           :: Word16             -- 2  Bytes. Not MACed
  , eitIsvSvnLe              :: Word16             -- 2  Bytes. Not MACed
  , eitReserved_byte212_235  :: L.ByteString       -- Reserved. Not MACed
  , eitMaskedMiscSelectLe    :: Word32             -- Returned by the Launch Enclave
  , eitMaskedAttributes      :: Attributes         -- Returned by the Launch Enclave
  , eitKeyId                 :: L.ByteString       -- 32-bytes of KeyID protection. Not MACed
  , eitMAC                   :: L.ByteString       -- 16 bytes of final MAC.
  }


newtype SigStructHeader = SSHeader{
  fromSSHeader :: Integer
}deriving(Show)

ssHeaderVal1 :: SigStructHeader
ssHeaderVal1 = SSHeader 0x06000000E100000000000100

ssHeaderVal2 :: SigStructHeader
ssHeaderVal2 = SSHeader 0x01010000600000006000000001000000


data SigStructVendor = SSVendorIntel
                     | SSVendorOther
                     deriving (Eq)

instance Show SigStructVendor where
  show SSVendorOther = "Other"
  show SSVendorIntel = "Intel"

instance Enum SigStructVendor where
  toEnum 0x8086 = SSVendorIntel
  toEnum 0x0    = SSVendorOther
  toEnum _      = undefined

  fromEnum SSVendorIntel = 0x8086
  fromEnum SSVendorOther = 0x0


data SigStructDate = SSDate {
  ssYear      :: Year
  ,  ssMonth  :: Month
  ,  ssDay    :: Day
  } deriving (Eq)


newtype Year = Year {
  yyyy :: Word16
  } deriving (Eq)


data Month = Jan | Feb | Mar | Apr
           | May | Jun | Jul | Aug
           | Sep | Oct | Nov | Dec
           | MartianMonth Int
           deriving(Show, Eq)

instance Enum Month where
  toEnum 1 = Jan
  toEnum 2 = Feb
  toEnum 3 = Mar
  toEnum 4 = Apr
  toEnum 5 = May
  toEnum 6 = Jun
  toEnum 7 = Jul
  toEnum 8 = Aug
  toEnum 9 = Sep
  toEnum 10 = Oct
  toEnum 11 = Nov
  toEnum 12 = Dec
  toEnum x  = MartianMonth x

  fromEnum Jan = 1
  fromEnum Feb = 2
  fromEnum Mar = 3
  fromEnum Apr = 4
  fromEnum May = 5
  fromEnum Jun = 6
  fromEnum Jul = 7
  fromEnum Aug = 8
  fromEnum Sep = 9
  fromEnum Oct = 10
  fromEnum Nov = 11
  fromEnum Dec = 12
  fromEnum (MartianMonth x) = x

  succ m = let m' = fromEnum m
           in if m' == 12
              then Jan
              else toEnum $ m'+1

  pred m = let m' = fromEnum m
           in if m' == 1
              then Dec
              else toEnum $ m'-1

data Day = Day Word8 deriving (Eq)

instance Enum Day where
  succ (Day x) = Day $ if x == 31
                       then 0
                       else succ x
  pred (Day x) = Day $ if x == 0
                       then 31
                       else pred x
  toEnum  = Day . fromIntegral
  fromEnum (Day x) = fromIntegral x


data TCS = TCS {
  tcsReserved_byte0_7        :: Word64
  , tcsFlags                 :: TCSFlags
  , tcsOSSA                  :: Word64
  , tcsCSSA                  :: Word32
  , tcsNSSA                  :: Word32
  , tcsOentry                :: Word64
  , tcsAep                   :: Word64
  , tcsOFSBasSgx             :: Word64
  , tcsOGSBasSgx             :: Word64
  , tcsFSLimit               :: Word32
  , tcsGSLimit               :: Word32
  --  , tcsReserved_byte72_4095  :: B.ByteString
  }

data TCSFlags = TCSFlags {
  tcsFlagsDebugOptIn          :: Bool
  , tcsFlagsReserved_bit1_63 :: Word64
  }

data SSAFrame = SSAFrame {
  ssaXsave    :: L.ByteString
  , ssaPad    :: L.ByteString
  , ssaMisc   :: L.ByteString
  , ssaGprSgx :: L.ByteString
  }

data GPRSGX = GPRSGX {
  gprRAX :: Word64
  , gprRCX    :: Word64
  , gprRDX    :: Word64
  , gprRBX    :: Word64
  , gprRSP    :: Word64
  , gprRBP    :: Word64
  , gprRSI    :: Word64
  , gprRDI    :: Word64
  , gprR8     :: Word64
  , gprR9     :: Word64
  , gprR10    :: Word64
  , gprR11    :: Word64
  , gprR12    :: Word64
  , gprR13    :: Word64
  , gprR14    :: Word64
  , gprR15    :: Word64
  , gprRFLAGS :: Word64
  , gprRIP    :: Word64
  , gprURSP   :: Word64
  , gprURBP   :: Word64
  , gprExitInfo :: ExitInfo
  , gprReserved_byte164_167 :: Word32
  , gprFsBase :: Word64
  , gprGsBase :: Word64
  }

data ExitInfo = ExitInfo {
  eiVector              :: ExcptVector
  , eiType              :: ExitInfoType
  , eiReserved_bit11_30 :: Word32
  , eiValid             :: Bool
  }

data ExitInfoType = ExitTypeHwExcept |
                    ExitTypeSwExcept

instance Enum ExitInfoType where
  fromEnum ExitTypeHwExcept = 0x3
  fromEnum ExitTypeSwExcept = 0x6

  toEnum 0x3 = ExitTypeHwExcept
  toEnum 0x6 = ExitTypeSwExcept
  toEnum _   = undefined

data ExcptVector = DividerExcpt
                 | DebugExcpt
                 | BreakpointExcpt
                 | BoundRangeExceedExcpt
                 | InvalidOpCodeExcpt
                 | GeneralProtectionExcpt
                 | PageFaultExcpt
                 | FPUErrorExcept
                 | AlignmentCheckExcept
                 | SIMDException
                 | UnknownExcptVector Int
                 deriving (Show, Eq)


instance Enum ExcptVector where
  fromEnum DividerExcpt           = 0
  fromEnum DebugExcpt             = 1
  fromEnum BreakpointExcpt        = 3
  fromEnum BoundRangeExceedExcpt  = 5
  fromEnum InvalidOpCodeExcpt     = 6
  fromEnum GeneralProtectionExcpt = 13
  fromEnum PageFaultExcpt         = 14
  fromEnum FPUErrorExcept         = 16
  fromEnum AlignmentCheckExcept   = 17
  fromEnum SIMDException          = 19
  fromEnum (UnknownExcptVector x) = x

  toEnum 0 = DividerExcpt
  toEnum 1 = DebugExcpt
  toEnum 3 = BreakpointExcpt
  toEnum 5 = BoundRangeExceedExcpt
  toEnum 6 = InvalidOpCodeExcpt
  toEnum 13 = GeneralProtectionExcpt
  toEnum 14 = PageFaultExcpt
  toEnum 16 = FPUErrorExcept
  toEnum 17 = AlignmentCheckExcept
  toEnum 19 = SIMDException
  toEnum x  = UnknownExcptVector x


data Report = Report {
  repCpuSvn                 :: CPUSVN         -- 16 Bytes
  , repMiscSelect           :: MiscSelect     -- 4 Bytes
  , repReserved_byte20_47   :: L.ByteString   -- reseved 28 bytes of Zero
  , repAttributes           :: Attributes     -- 16 bytes
  , repMrEnclave            :: L.ByteString   -- 32 bytes
  , repReserved_byte96_127  :: L.ByteString   -- 32 bytes of zero
  , repMrSigner             :: L.ByteString   -- 32 bytes of signger
  , repReserved_byte160_255 :: L.ByteString   -- 32 bytes of zero
  , repIsvProdId            :: Word16         -- 2 bytes
  , repIsvSvn               :: Word16         -- 2 bytes
  , repReserved_byte260_319 :: L.ByteString   -- 60 bytes of zero
  , repReportData           :: L.ByteString   -- 64 bytes of report data
  , repKeyId                :: L.ByteString   -- 32-bytes of key id
  , repMAC                  :: L.ByteString   -- 16-bytes of Mac
  }


newtype CPUSVN = CPUSVN {
  cpuSvnValue :: L.ByteString
  }

instance Show CPUSVN where
  show (CPUSVN x) = "0x" ++ toHexRep x

data TargetInfo = TargetInfo {
  tiTargetMrEnclave       :: L.ByteString        -- 32 bytes of MrEnclave
  , tiAttributes          :: Attributes          -- 16 bytes of attributes
  , tiReserved_byte48_51  :: Word32              -- 4 bytes reserved
  , tiMiscSelect          :: MiscSelect          -- 4 bytes of MiscSelect
  , tiReserved_byte56_511 :: L.ByteString        -- Reserved to zero
  }


data KeyRequest = KeyRequest {
  krKeyName               :: KeyName              -- 2 bytes
  , krKeyPolicy           :: KeyPolicy            -- 2 bytes
  , krIsvSvn              :: Word16               -- 2 bytes
  , krReserved_byte6_7    :: Word16               -- 2 bytes
  , krCpuSvn              :: CPUSVN               -- 16 bytes
  , krAttributeMask       :: Attributes           -- 16 bytes
  , krKeyId               :: L.ByteString         -- 32 bytes
  , krMiscMask            :: MiscSelect           -- 4 bytes
  , krReserved_byte76_511 :: L.ByteString         -- 436 bytes of zero
  }


data KeyName = EINIT_TOKEN_KEY
             | PROVISION_KEY
             | PROVISION_SEAL_KEY
             | REPORT_KEY
             | SEAL_KEY
             | INVALID_KEY_ID Int
             deriving (Show, Eq)

instance Enum KeyName where
  toEnum 0 = EINIT_TOKEN_KEY
  toEnum 1 = PROVISION_KEY
  toEnum 2 = PROVISION_SEAL_KEY
  toEnum 3 = REPORT_KEY
  toEnum 4 = SEAL_KEY
  toEnum x = INVALID_KEY_ID x

  fromEnum EINIT_TOKEN_KEY     = 0
  fromEnum PROVISION_KEY       = 1
  fromEnum PROVISION_SEAL_KEY  = 2
  fromEnum REPORT_KEY          = 3
  fromEnum SEAL_KEY            = 4
  fromEnum (INVALID_KEY_ID x)  = x

data KeyPolicy = KeyPolicy {
  kpIsMrEnclave :: Bool
  , kpIsMrSigner :: Bool
  , kpReserved_bit2_15 :: Word16
  }


instance Show Year where
  show (Year y) =
    printf "%d" (fromIntegral y :: Int)

instance Show Day where
  show (Day d) = show d

data EnclaveMetadata = EnclaveMetadata
  {
    metaMagicNum       :: !Word64
  , metaVersion         :: !Word64
  , metaSize           :: !Word32
  , metaTCSPolicy      :: !Word32
  , metaSSAFrameSize   :: !Word32
  , metaMaxSaveSize    :: !Word32
  , metaDesiredMiscSel :: !Word32
  , metaTCSMinPool     :: !Word32
  , metaEnclaveSize    :: !Word64
  , metaAttributes     :: Attributes
  , metaEnclaveCSS     :: SigStruct
  , metaDataDirectory  :: [DataDirectory]
  , metaPatches        :: [PatchEntry]
  , metaLayouts        :: [LayoutEntry]
  }deriving(Show)


data DataDirectory = DataDirectory
  {
    ddOffset :: !Word32
  , ddSize   :: !Word32
  }deriving(Show)


data PatchEntry = PatchEntry
  {
    patchDest    :: !Word64
  , patchSource  :: !Word32
  , patchSize    :: !Word32
  , patchData    :: B.ByteString
  }deriving(Show)

data LayoutIdentity =
  LAYOUT_ID_ELF_SEGMENT
  | LAYOUT_ID_HEAP_MIN
  | LAYOUT_ID_HEAP_INIT
  | LAYOUT_ID_HEAP_MAX
  | LAYOUT_ID_TCS
  | LAYOUT_ID_TD
  | LAYOUT_ID_SSA
  | LAYOUT_ID_STACK_MAX
  | LAYOUT_ID_STACK_MIN
  | LAYOUT_ID_GUARD
  | LAYOUT_ID_HEAP_DYN_MIN
  | LAYOUT_ID_HEAP_DYN_INIT
  | LAYOUT_ID_HEAP_DYN_MAX
  | LAYOUT_ID_TCS_DYN
  | LAYOUT_ID_TD_DYN
  | LAYOUT_ID_SSA_DYN
  | LAYOUT_ID_STACK_DYN_MAX
  | LAYOUT_ID_STACK_DYN_MIN
  -- groups
  | LAYOUT_ID_THREAD_GROUP
  | LAYOUT_ID_THREAD_GROUP_DYN
  | LAYOUT_ID_UNKNOWN Int
  deriving(Eq, Show)

data LayoutOperations =
  E_ADD
  | E_EXTEND
  | E_REMOVE
  | E_POSTADD
  | E_POSTREMOVE
  | E_DYNTHREAD
  | E_GROWDOWN
  deriving(Eq, Show)

data LayoutEntry =
  LayoutEntry {
    lentryID        :: !LayoutIdentity
  , lentryOps       :: [LayoutOperations]
  , lentryPageCount :: !Word32 -- map size as number of pages
  , lentryRVA       :: !Word64 -- map offset relative
                               -- to enclave base
  , lentryContent   :: B.ByteString -- Content if any
  , lentryContentSz :: !Word32 -- Content size or
                               -- value to fill page

  , lentryContentOff:: !Word32 -- Offset of initial
                               -- content relative
                               -- to metadata
  , lentryPermFlags :: [SecInfoFlags]
  } | LayoutGroup {
    lgrpID          :: !LayoutIdentity
  , lgrpEntryCount  :: !Word16
  , lgrpLoadTimes   :: !Word32
  , lgrpLoadStep    :: !Word64
  , lgrpReserved    :: [Word32]
  }
  deriving(Show)

extractFlags :: (Integral a, Bits a, Enum b) => a
             -> [b]
extractFlags w = extractOpts w 0 [] where
  extractOpts :: (Integral a, Enum b, Bits a) => a
              -> Int
              -> [b]
              -> [b]
  extractOpts w' n ys | w' == 0     = ys
                      | otherwise   =
                          let isSet = w' .&. 0x1 == 0x1
                              flag  = toEnum n
                              w''   = w' `shiftR` 1
                          in if isSet
                          then extractOpts w'' (n+1)
                                              (flag:ys)
                          else extractOpts w'' (n+1) ys
{-# INLINE extractFlags #-}

encodeFlags :: (Enum a, Integral b, Bits b)
            => [a]
            -> b
encodeFlags = foldr' (\ x y -> shiftL 1 (fromEnum x) .|. y) 0
{-# INLINE encodeFlags #-}

instance Enum LayoutOperations where
  toEnum 0 = E_ADD
  toEnum 1 = E_EXTEND
  toEnum 2 = E_REMOVE
  toEnum 3 = E_POSTADD
  toEnum 4 = E_POSTREMOVE
  toEnum 5 = E_DYNTHREAD
  toEnum 6 = E_GROWDOWN
  toEnum _ = undefined

  fromEnum E_ADD     = 0
  fromEnum E_EXTEND  = 1
  fromEnum E_REMOVE  = 2
  fromEnum E_POSTADD = 3
  fromEnum E_POSTREMOVE = 4
  fromEnum E_DYNTHREAD = 5
  fromEnum E_GROWDOWN = 6

instance Enum LayoutIdentity where
  fromEnum LAYOUT_ID_ELF_SEGMENT   = 0
  fromEnum LAYOUT_ID_HEAP_MIN      = 1
  fromEnum LAYOUT_ID_HEAP_INIT     = 2
  fromEnum LAYOUT_ID_HEAP_MAX      = 3
  fromEnum LAYOUT_ID_TCS           = 4
  fromEnum LAYOUT_ID_TD            = 5
  fromEnum LAYOUT_ID_SSA           = 6
  fromEnum LAYOUT_ID_STACK_MAX     = 7
  fromEnum LAYOUT_ID_STACK_MIN     = 8
  fromEnum LAYOUT_ID_THREAD_GROUP  = groupId 9
  fromEnum LAYOUT_ID_GUARD         = 10
  fromEnum LAYOUT_ID_HEAP_DYN_MIN  = 11
  fromEnum LAYOUT_ID_HEAP_DYN_INIT = 12
  fromEnum LAYOUT_ID_HEAP_DYN_MAX  = 13
  fromEnum LAYOUT_ID_TCS_DYN       = 14
  fromEnum LAYOUT_ID_TD_DYN        = 15
  fromEnum LAYOUT_ID_SSA_DYN       = 16
  fromEnum LAYOUT_ID_STACK_DYN_MAX    = 17
  fromEnum LAYOUT_ID_STACK_DYN_MIN    = 18
  fromEnum LAYOUT_ID_THREAD_GROUP_DYN = groupId 19
  fromEnum (LAYOUT_ID_UNKNOWN x)   = x

  toEnum 0 = LAYOUT_ID_ELF_SEGMENT
  toEnum 1 = LAYOUT_ID_HEAP_MIN
  toEnum 2 = LAYOUT_ID_HEAP_INIT
  toEnum 3 = LAYOUT_ID_HEAP_MAX
  toEnum 4 = LAYOUT_ID_TCS
  toEnum 5 = LAYOUT_ID_TD
  toEnum 6 = LAYOUT_ID_SSA
  toEnum 7 = LAYOUT_ID_STACK_MAX
  toEnum 8 = LAYOUT_ID_STACK_MIN
  toEnum 10 = LAYOUT_ID_GUARD
  toEnum 11 = LAYOUT_ID_HEAP_DYN_MIN
  toEnum 12 = LAYOUT_ID_HEAP_DYN_INIT
  toEnum 13 = LAYOUT_ID_HEAP_DYN_MAX
  toEnum 14 = LAYOUT_ID_TCS_DYN
  toEnum 15 = LAYOUT_ID_TD_DYN
  toEnum 16 = LAYOUT_ID_SSA_DYN
  toEnum 17 = LAYOUT_ID_STACK_DYN_MAX
  toEnum 18 = LAYOUT_ID_STACK_DYN_MIN
  toEnum x  | groupId 9  == x = LAYOUT_ID_THREAD_GROUP
            | groupId 19 == x = LAYOUT_ID_THREAD_GROUP_DYN
  toEnum y  = (LAYOUT_ID_UNKNOWN y)

groupFlag :: Int
groupFlag = 1 `shiftL` 12

groupId :: Int -> Int
groupId n = n .|. groupFlag

isGroupId16 :: Word16 -> Bool
isGroupId16 w = (groupFlag .&. (fromIntegral w)) /= 0

isGroupId :: LayoutIdentity -> Bool
isGroupId e = groupFlag .&. fromEnum e /= 0

data SecInfoFlags =
  SI_FLAG_R
  | SI_FLAG_W
  | SI_FLAG_X
  | SI_FLAG_PENDING
  | SI_FLAG_MODIFIED
  | SI_FLAG_PR
  | SI_FLAG_SECS
  | SI_FLAG_TCS
  | SI_FLAG_REG
  | SI_FLAG_VA
  | SI_FLAG_TRIM
  | PermUnknown Int
  deriving(Show, Eq)


instance Enum SecInfoFlags where
  fromEnum SI_FLAG_R        = 0  -- These are bit positions
  fromEnum SI_FLAG_W        = 1
  fromEnum SI_FLAG_X        = 2
  fromEnum SI_FLAG_PENDING  = 3
  fromEnum SI_FLAG_MODIFIED = 4
  fromEnum SI_FLAG_PR       = 5
  fromEnum SI_FLAG_SECS     = 7
  fromEnum SI_FLAG_TCS      = 8
  fromEnum SI_FLAG_REG      = 9
  fromEnum SI_FLAG_VA       = 10
  fromEnum SI_FLAG_TRIM     = 11
  fromEnum (PermUnknown k)  = k

  toEnum 0  = SI_FLAG_R
  toEnum 1  = SI_FLAG_W
  toEnum 2  = SI_FLAG_X
  toEnum 3  = SI_FLAG_PENDING
  toEnum 4  = SI_FLAG_MODIFIED
  toEnum 5  = SI_FLAG_PR
  toEnum 7  = SI_FLAG_SECS
  toEnum 8  = SI_FLAG_TCS
  toEnum 9 = SI_FLAG_REG
  toEnum 10 = SI_FLAG_VA
  toEnum 11 = SI_FLAG_TRIM
  toEnum k  = PermUnknown k


getBytesToDate :: Word32 -> SigStructDate
getBytesToDate w =
  let
    extractNibble :: Word32 -> Int -> Int
    extractNibble x n = fromIntegral
                        ((x `shiftR` n) .&. 0xf)
    y1 = extractNibble w 28
    y2 = extractNibble w 24
    y3 = extractNibble w 20
    y4 = extractNibble w 16
    m1 = extractNibble w 12
    m2 = extractNibble w 8
    d1 = extractNibble w 4
    d2 = extractNibble w 0
    year = y1 * 1000 + y2 * 100 + y3 * 10 + y4
    month = m1*10 + m2
    day   = d1*10 + d2
  in
    SSDate (Year (fromIntegral year)) (toEnum month) (toEnum day)


instance Show SigStructDate where
  show (SSDate y m d) = (show d) ++ "-" ++
                        (show m) ++ "-" ++
                        (show y)
