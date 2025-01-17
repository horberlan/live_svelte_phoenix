import Onboard from '@web3-onboard/core'
import phantomModule from '@web3-onboard/phantom'

// initialize the module
const phantom = phantomModule()

const onboard = Onboard({
  // ... other Onboard options
  wallets: [
    phantom
    //... other wallets
  ]
})

const connectedWallets = await onboard.connectWallet()
console.log(connectedWallets)