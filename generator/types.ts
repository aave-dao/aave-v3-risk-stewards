import * as addressBook from '@bgd-labs/aave-address-book';
import {
  CapsUpdate,
  CollateralUpdate,
  LstPriceCapUpdate,
  RateStrategyUpdate,
  StablePriceCapUpdate,
} from './features/types';

export const V3_POOLS = [
  'AaveV3Ethereum',
  'AaveV3EthereumLido',
  'AaveV3EthereumEtherFi',
  'AaveV3Polygon',
  'AaveV3Avalanche',
  'AaveV3Optimism',
  'AaveV3Arbitrum',
  'AaveV3Metis',
  'AaveV3Base',
  'AaveV3Gnosis',
  'AaveV3Scroll',
  'AaveV3BNB',
  'AaveV3ZkSync',
  'AaveV3Linea',
  'AaveV3Sonic',
  'AaveV3Celo',
] as const satisfies readonly (keyof typeof addressBook)[];

export const POOLS = [...V3_POOLS] as const satisfies readonly (keyof typeof addressBook)[];

export type PoolIdentifier = (typeof POOLS)[number];
export type PoolIdentifierV3 = (typeof V3_POOLS)[number];

export interface Options {
  force?: boolean;
  pools: PoolIdentifier[];
  title: string;
  // automatically generated shortName from title
  shortName: string;
  author: string;
  discussion: string;
  configFile?: string;
  date: string;
}

export type PoolConfigs = Partial<Record<PoolIdentifier, PoolConfig>>;

export type CodeArtifact = {
  code?: {
    constants?: string[];
    fn?: string[];
    execute?: string[];
  };
};

export enum FEATURE {
  CAPS_UPDATE = 'CAPS_UPDATE',
  COLLATERALS_UPDATE = 'COLLATERALS_UPDATE',
  RATE_UPDATE_V3 = 'RATE_UPDATE_V3',
  LST_PRICE_CAP_UPDATE = 'LST_PRICE_CAP_UPDATE',
  STABLE_PRICE_CAP_UPDATE = 'STABLE_PRICE_CAP_UPDATE',
}

export interface FeatureModule<T extends {} = {}> {
  description: string;
  value: FEATURE;
  cli: (args: {options: Options; pool: PoolIdentifier; cache: PoolCache}) => Promise<T>;
  build: (args: {options: Options; pool: PoolIdentifier; cache: PoolCache; cfg: T}) => CodeArtifact;
}

export const ENGINE_FLAGS = {
  KEEP_CURRENT: 'KEEP_CURRENT',
  KEEP_CURRENT_STRING: 'KEEP_CURRENT_STRING',
  KEEP_CURRENT_ADDRESS: 'KEEP_CURRENT_ADDRESS',
  ENABLED: 'ENABLED',
  DISABLED: 'DISABLED',
} as const;

export const AVAILABLE_VERSIONS = {V3: 'V3'} as const;

export type ConfigFile = {
  rootOptions: Options;
  poolOptions: Partial<Record<PoolIdentifier, Omit<PoolConfig, 'artifacts'>>>;
};

export type PoolCache = {blockNumber: number};

export interface PoolConfig {
  artifacts: CodeArtifact[];
  configs: {
    [FEATURE.CAPS_UPDATE]?: CapsUpdate[];
    [FEATURE.COLLATERALS_UPDATE]?: CollateralUpdate[];
    [FEATURE.RATE_UPDATE_V3]?: RateStrategyUpdate[];
    [FEATURE.LST_PRICE_CAP_UPDATE]?: LstPriceCapUpdate[];
    [FEATURE.STABLE_PRICE_CAP_UPDATE]?: StablePriceCapUpdate[];
  };
  cache: PoolCache;
}

export type Files = {
  jsonConfig: string;
  payloads: {pool: PoolIdentifier; payload: string; contractName: string}[];
};
