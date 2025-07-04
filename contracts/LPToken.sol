// SPDX-License-Identifier: MIT
// Desarrollado por María José Atencio
// Compatible con OpenZeppelin Contracts ^5.0.0

pragma solidity ^0.8.22;

// 🧱 Heredamos la funcionalidad de ERC20 para el token base
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// 👑 Añadimos control de propiedad para permitir funciones exclusivas del owner
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title LP Token (LPT) - Token de liquidez para staking en la plataforma
/// @author María José Atencio
/// @notice Solo el owner (la plataforma) puede mintear estos tokens mock para simular depósitos LP
contract LPToken is ERC20, Ownable {

    /// @dev Inicializa el token con nombre y símbolo, y establece el owner del contrato
    /// @param initialOwner Dirección del owner (usualmente quien despliega este contrato)
    constructor(address initialOwner) ERC20("LP Token", "LPT") Ownable(initialOwner) {}

    /// @notice Permite al owner mintear tokens LP para pruebas o distribución inicial
    /// @param to Dirección del destinatario
    /// @param amount Cantidad de tokens (en wei) a mintear
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
