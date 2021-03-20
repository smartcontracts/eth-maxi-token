import { HardhatUserConfig } from 'hardhat/types'

import 'hardhat-deploy'

const config: HardhatUserConfig = {
  solidity: {
    version: '0.7.6'
  },
  networks: {
    hardhat: {
      accounts: [
        {
          privateKey: '0x1111111111111111111111111111111111111111111111111111111111111111',
          balance: '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
        }
      ],
      live: false,
      saveDeployments: false,
      tags: ['test', 'local'],
    },
    kovan: {
      url: '',
      accounts: [
        '0x1111111111111111111111111111111111111111111111111111111111111111'
      ],
      live: true,
      saveDeployments: true,
      tags: ['test', 'kovan'],
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
}

export default config
