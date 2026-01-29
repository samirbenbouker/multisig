4. Multisig Wallet (simple)
Un wallet donde N de M firmas ejecutan transacciones.
Practicas:
* Structs complejos
* Firmas y confirmaciones
* Tests con múltiples actores
Extras:
* Replay protection
* Tests fuzz para confirmaciones


Funcionalidades que debería tener
    Core (MVP imprescindible)
        Owners + threshold
            owners[] y isOwner[address]
            threshold (N), con 1 <= threshold <= owners.length
            Constructor valida duplicados, address(0), threshold inválido
        Receive ETH
            receive() para aceptar ETH
        Proponer transacción
            submit(to, value, data) crea una txId
            Guarda en un struct:
                to, value, data
                executed bool
                numConfirmations
                opcional: nonce o createdAt
            Evento Submit(txId, to, value, data)

    Confirmar / Revocar
        confirm(txId) solo owner, no ejecutada, no confirmada antes
        revoke(txId) solo owner, no ejecutada, debe estar confirmada
        Eventos Confirm(owner, txId) / Revoke(owner, txId)
    Ejecutar
        execute(txId) solo owner (o cualquiera, tú decides), requiere numConfirmations >= threshold, no ejecutada
        Hace call{value}(data)
        Marca executed = true antes del call (CEI) o usa nonReentrant
        Evento Execute(txId, success, returnData) o Execute(txId)
    Views
        getOwners(), getTx(txId), isConfirmed(txId, owner) etc.

Con esto ya es un multisig sólido para practicar.


Extras que valen mucho (elige 1–3)
A) Replay protection / nonce
    Si el multisig firma “off-chain” o si quieres robustez:
    txHash = keccak256(chainId, multisigAddress, nonce, to, value, keccak256(data))
    nonce++ al ejecutar
    Evita replays cross-chain/cross-contract
B) EIP-712 signatures (modo “sin confirmaciones on-chain”)
    Owners firman un mensaje
    executeWithSigs(to, value, data, nonce, sigs[])
    Verificas que hay N firmas únicas de owners
C) Batch
    Ejecutar varias tx en una sola (útil para gas y práctica de arrays)
D) ERC20 / ERC721 helper
    No es necesario, pero te da práctica con data para calls