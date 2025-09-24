import * as addressBook from '@bgd-labs/aave-address-book';
import {Options, PoolIdentifier, PoolIdentifierV3} from './types';
import {
  arbitrum,
  avalanche,
  mainnet,
  metis,
  optimism,
  polygon,
  base,
  bsc,
  gnosis,
  scroll,
  zkSync,
  linea,
  sonic,
  celo,
  soneium,
  plasma,
} from 'viem/chains';

export const AVAILABLE_CHAINS = [
  'Ethereum',
  'Optimism',
  'Arbitrum',
  'Polygon',
  'Avalanche',
  'Fantom',
  'Harmony',
  'Metis',
  'Base',
  'BNB',
  'Gnosis',
  'Scroll',
  'ZkSync',
  'Linea',
  'Sonic',
  'Celo',
  'Soneium',
  'Plasma',
] as const;

export function getAssets(pool: PoolIdentifier): string[] {
  const assets = addressBook[pool].ASSETS;
  return Object.keys(assets);
}

export function getEModes(pool: PoolIdentifierV3): {value: string; id: number}[] {
  return Object.keys(addressBook[pool].E_MODES).map((key) => ({
    // map the complex type to a string as used in the sol libs
    value: addressBook[pool].E_MODES[key].label.toUpperCase().replace(/[^A-Z0-9]+/gi, '_'),
    id: key as unknown as number,
  }));
}

export function getVersion(pool: PoolIdentifier) {
  return 'V3';
}

export function getPoolChain(pool: PoolIdentifier) {
  const chain = AVAILABLE_CHAINS.find((chain) => pool.indexOf(chain) !== -1);
  if (!chain) throw new Error('cannot find chain for pool');
  return chain;
}

export function getPoolSuffix(pool: PoolIdentifier) {
  return pool.replace('AaveV3', '');
}

export function getDate() {
  const date = new Date();
  const years = date.getFullYear();
  const months = date.getMonth() + 1; // it's js so months are 0 indexed
  const day = date.getDate();
  return `${years}${months <= 9 ? '0' : ''}${months}${day <= 9 ? '0' : ''}${day}`;
}

/**
 * Prefix with the date for proper sorting
 * @param {*} options
 * @returns
 */
export function generateFolderName(options: Options) {
  return `${options.date}_${options.pools.length === 1 ? options.pools[0] : 'Multi'}_${
    options.shortName
  }`;
}

/**
 * Suffix with the date as prefixing would generate invalid contract names
 * @param {*} options
 * @param {*} chain
 * @returns
 */
export function generateContractName(options: Options, pool?: PoolIdentifier) {
  let name = pool ? `${pool}_` : '';
  name += `${options.shortName}`;
  name += `_${options.date}`;
  return name;
}

export function getChainAlias(chain) {
  return chain === 'Ethereum' ? 'mainnet' : chain.toLowerCase();
}

export function pascalCase(str: string) {
  return str
    .replace(/[\W]/g, ' ') // remove special chars as this is used for solc contract name
    .replace(/(\w)(\w*)/g, function (g0, g1, g2) {
      return g1.toUpperCase() + g2;
    })
    .replace(/ /g, '');
}

export const CHAIN_TO_CHAIN_ID = {
  Ethereum: mainnet.id,
  Polygon: polygon.id,
  Optimism: optimism.id,
  Arbitrum: arbitrum.id,
  Avalanche: avalanche.id,
  Metis: metis.id,
  Base: base.id,
  BNB: bsc.id,
  Gnosis: gnosis.id,
  Scroll: scroll.id,
  ZkSync: zkSync.id,
  Linea: linea.id,
  Sonic: sonic.id,
  Celo: celo.id,
  Soneium: soneium.id,
  Plasma: plasma.id,
};

export function flagAsRequired(message: string, required?: boolean) {
  return required ? `${message}*` : message;
}
