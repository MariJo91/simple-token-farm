// SPDX-License-Identifier: MIT
// Desarrollado por María José Atencio
// Compatible con OpenZeppelin Contracts ^5.0.0

pragma solidity ^0.8.22;

// 🪙 Importamos la lógica ERC20 básica y el control de propiedad
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title DApp Token (DAPP) - Token de recompensas de la plataforma
/// @author María José Atencio
/// @notice Solo el owner (la plataforma) puede mintear tokens para entregar como recompensa
contract DappToken is ERC20, Ownable {
    
    /// @dev Se establece el nombre y símbolo del token heredado de ERC20
    /// @param initialOwner Dirección que será la dueña del contrato (normalmente quien despliega)
    constructor(address initialOwner) ERC20("DApp Token", "DAPP") Ownable(initialOwner) {}

    /// @notice Función para mintear nuevos tokens DAPP
    /// @dev Solo accesible por el owner (gracias al modifier onlyOwner de OpenZeppelin)
    /// @param to Dirección que recibirá los tokens minteados
    /// @param amount Cantidad de tokens (en wei) a mintear
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
