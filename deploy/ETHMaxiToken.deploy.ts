import * as rlp from 'rlp'
import { BlockHeader } from '@ethereumjs/block'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { serializeTransaction } from 'ethers/lib/utils'
import { Transaction } from 'ethers'

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
      block.stateRoot
    ],
    log: true,
    gasLimit: 4_000_000
  })

  const proof = await hre.network.provider.send('eth_getProof', [
    deployer,
    [],
    '0x' + block.number.toString('hex')
  ])

  const instance = await (hre.ethers as any).getContract('ETHMaxiToken')

  const transaction: Transaction = await instance.claim(
    deployer,
    rlp.encode(proof.accountProof),
    {
      gasLimit: 2_000_000
    }
  )
  await (transaction as any).wait()

  console.log(await instance.balanceOf(deployer))

  const signedTransaction = serializeTransaction({
    to: transaction.to,
    nonce: transaction.nonce,
    gasLimit: transaction.gasLimit,
    gasPrice: transaction.gasPrice,
    data: transaction.data,
    value: transaction.value,
    chainId: transaction.chainId
  }, {
    v: transaction.v,
    r: transaction.r,
    s: transaction.s
  })

  const tx = await instance.slash(
    signedTransaction,
    transaction.chainId,
    {
      gasLimit: 2_000_000
    }
  )
  await tx.wait()

  console.log(await instance.balanceOf(deployer))
}

deployFn.tags = ['ETHMaxiToken', 'required']

export default deployFn
