# 🧑‍🌾 Simple Token Farm – Staking DApp con Recompensas Proporcionales

Este proyecto implementa un sistema de **staking de tokens LP** donde los usuarios reciben **recompensas en DAPP tokens** de forma proporcional a su participación. Está desarrollado con **Solidity** y utiliza el entorno de desarrollo **Hardhat** para pruebas, despliegue y automatización.

---

## 📦 Características principales

- ✅ Staking de tokens LP por parte de los usuarios
- 🔁 Recompensas calculadas proporcionalmente al total stakeado y tiempo bloqueado
- 💸 Acumulación y reclamo de recompensas en DAPP tokens
- 🧠 Control automático de check-points por bloque para máxima precisión
- 🔐 Modificadores de seguridad `onlyOwner` y `onlyStaker`
- 🧪 Pruebas unitarias completas incluidas (`Bonus 3`)
- ✨ Código optimizado con `struct` para manejo de datos (`Bonus 2`)

---

## 🚀 Estado del proyecto

✔️ Contratos compilados correctamente  
✔️ Pruebas iniciales ejecutadas con resultados positivos  
❗ Algunas pruebas pendientes de revisión y mejora  
📦 Aún no desplegado en red de pruebas (solo entorno local)

---

## 🛠 Tecnologías utilizadas

- [Hardhat](https://hardhat.org/)
- Solidity ^0.8.22
- Chai / Mocha (pruebas)
- Ethers.js
- VS Code

---

## 📁 Estructura del proyecto

contracts/  
    ├── DappToken.sol 
    ├── LPToken.sol 
    ├── TokenFarm.sol test/ 
    ├── TokenFarm.test.js scripts/ 
    ├── deploy.js hardhat.config.js 
README.m


## 🚀 ¿Cómo ejecutar este proyecto?

### 1. Clonar el repositorio

# bash
git clone https://github.com/MariJo91/simple-token-farm.git
cd simple-token-farm
npm install

### 🧪 Ejecutar pruebas localmente

# bash
npx hardhat compile
npx hardhat node          # En terminal separada
npx hardhat test

