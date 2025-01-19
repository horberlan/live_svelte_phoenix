<script>
  import { onMount } from 'svelte'

  export let live

  $: isPhantomInstalled = false
  let pubKey = null

  let Anywindow
  let provider
  export let canCreateSession = pubKey ? true : false

  onMount(() => {
    Anywindow = window
    isPhantomInstalled = Anywindow?.phantom?.solana?.isPhantom

    provider = getProvider()
  })

  const getProvider = () => {
    if (Anywindow && 'phantom' in Anywindow) {
      const provider = Anywindow.phantom?.solana

      if (provider?.isPhantom) {
        return provider
      }
    }
  }

  const handleConnect = async () => {
    if (!provider) {
      Anywindow.open('https://phantom.app/', '_blank')
      return
    }

    try {
      const resp = await provider.connect()
      pubKey = resp.publicKey.toString()
      canCreateSession = true
      live.pushEvent('connect', { pubKey: pubKey })
    } catch (error) {
      console.error('Connection error:', error)
      return { code: 4001, message: 'User rejected the request.', _raw: error }
    }
  }

  const handleDisconnect = async () => {
    if (!provider) return
    await provider
      .disconnect()
      .then(() => {
        pubKey = null
        canCreateSession = false
      })
      .catch((e) => {
        console.log(e)
      })
  }

  const maskPublicKey = (publicKey) => {
    if (!publicKey) return ''
    const firstFew = publicKey.substring(0, 4)
    const lastFew = publicKey.substring(publicKey.length - 4)
    return `${firstFew}...${lastFew}`
  }

  const intl = {
    connect: 'Connect Wallet',
    falseIsPhantomInstalled: 'Install Phantom Wallet',
  }
</script>

{#if !pubKey}
  <button class="btn flex items-center space-x-2" on:click={handleConnect}>
    {#if isPhantomInstalled}
      <span>{intl.connect}</span>
    {:else}
      <span>{intl.falseIsPhantomInstalled}</span>
    {/if}
  </button>
{:else}
  <button class="btn flex items-center space-x-2" on:click={handleDisconnect}>
    <span>{maskPublicKey(pubKey)}</span>
  </button>
{/if}
