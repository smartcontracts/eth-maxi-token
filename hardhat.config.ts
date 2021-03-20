import { HardhatUserConfig } from 'hardhat/types'

import '@nomiclabs/hardhat-ethers'
import 'hardhat-deploy'
import 'hardhat-deploy-ethers'

const config: HardhatUserConfig = {
  solidity: {
    version: '0.7.6'
  },
  networks: {
    hardhat: {
      accounts: [
        {
          privateKey: '',
          balance: '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
        }
      ],
      live: false,
      saveDeployments: false,
      tags: ['test', 'local'],
    },
    goerli: {
      url: 'https://goerli.infura.io/v3/',
      accounts: [
        ''
      ],
      live: true,
      saveDeployments: true,
      tags: ['test', 'goerli'],
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
}

export default config
