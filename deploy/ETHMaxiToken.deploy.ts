import { BlockHeader } from '@ethereumjs/block'
import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const { deploy } = hre.deployments
  const { deployer } = await hre.getNamedAccounts()

  const block = BlockHeader.fromHeaderData(
    await hre.network.provider.send('eth_getBlockByNumber', [
      'latest',
      false
    ])
  )

  const contract = await deploy('ETHMaxiToken', {
    from: deployer,
    args: [
      0, // _lockupPeriod
      block.number.toNumber(),
      block.serialize()
    ],
    log: true,
    gasLimit: 8_000_000
  })

  const block2 = BlockHeader.fromHeaderData(
    await hre.network.provider.send('eth_getBlockByNumber', [
      'latest',
      false
    ])
  )

  console.log(block2)

  console.log(contract)
}

deployFn.tags = ['ETHMaxiToken', 'required']

export default deployFn
