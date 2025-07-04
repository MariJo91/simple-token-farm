const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TokenFarm - Pruebas de Bonus 3", function () {
  let owner, alice, bob;
  let lpToken, dappToken, tokenFarm;

beforeEach(async function () {
  [owner, alice, bob] = await ethers.getSigners();

  // 1. Desplegar LPToken con el owner como minter
  const LPToken = await ethers.getContractFactory("LPToken");
  lpToken = await LPToken.connect(owner).deploy(owner.address);

  // 2. Desplegar DappToken con el owner como minter
  const DappToken = await ethers.getContractFactory("DappToken");
  dappToken = await DappToken.connect(owner).deploy(owner.address);

  // 3. Desplegar TokenFarm apuntando a los contratos anteriores
  const TokenFarm = await ethers.getContractFactory("TokenFarm");
  tokenFarm = await TokenFarm.connect(owner).deploy(
    dappToken.target,
    lpToken.target
  );

  // 4. Transferir el ownership del DappToken a TokenFarm para que pueda mintear
  await dappToken.connect(owner).transferOwnership(tokenFarm.address);

  // 5. Mintear LP tokens para los usuarios de prueba
  await lpToken.connect(owner).mint(alice.address, ethers.parseEther("100"));
  await lpToken.connect(owner).mint(bob.address, ethers.parseEther("100"));
});


  it("✅ Acuñar y depositar LP Tokens por un usuario", async function () {
    await lpToken.connect(alice).approve(tokenFarm.address, ethers.parseEther("50"));
    await tokenFarm.connect(alice).deposit(ethers.parseEther("50"));

    const balanceEnFarm = await lpToken.balanceOf(tokenFarm.address);
    const stakingAlice = await tokenFarm.getStakingBalance(alice.address);

    expect(balanceEnFarm).to.equal(ethers.parseEther("50"));
    expect(stakingAlice).to.equal(ethers.parseEther("50"));
  });

  it("✅ Distribuir recompensas entre múltiples usuarios", async function () {
    await lpToken.connect(alice).approve(tokenFarm.address, ethers.parseEther("40"));
    await tokenFarm.connect(alice).deposit(ethers.parseEther("40"));

    await ethers.provider.send("evm_mine"); // Simulamos bloque

    await lpToken.connect(bob).approve(tokenFarm.address, ethers.parseEther("60"));
    await tokenFarm.connect(bob).deposit(ethers.parseEther("60"));

    // Esperamos unos bloques simulados
    for (let i = 0; i < 5; i++) {
      await ethers.provider.send("evm_mine");
    }

    await tokenFarm.connect(owner).distributeRewardsAll();

    const rewardsAlice = await tokenFarm.getPendingRewards(alice.address);
    const rewardsBob = await tokenFarm.getPendingRewards(bob.address);

    expect(rewardsAlice).to.be.gt(0);
    expect(rewardsBob).to.be.gt(rewardsAlice);
  });

  it("✅ Reclamar recompensas y verificar transferencia de DAPP tokens", async function () {
    await lpToken.connect(alice).approve(tokenFarm.address, ethers.parseEther("20"));
    await tokenFarm.connect(alice).deposit(ethers.parseEther("20"));

    for (let i = 0; i < 3; i++) {
      await ethers.provider.send("evm_mine");
    }

    await tokenFarm.connect(owner).distributeRewardsAll();
    const before = await dappToken.balanceOf(alice.address);

    await tokenFarm.connect(alice).claimRewards();
    const after = await dappToken.balanceOf(alice.address);

    expect(after).to.be.gt(before);
  });

  it("✅ Deshacer staking y conservar recompensas pendientes", async function () {
    await lpToken.connect(alice).approve(tokenFarm.address, ethers.parseEther("25"));
    await tokenFarm.connect(alice).deposit(ethers.parseEther("25"));

    for (let i = 0; i < 4; i++) {
      await ethers.provider.send("evm_mine");
    }

    await tokenFarm.connect(owner).distributeRewardsAll();

    const rewardsAntes = await tokenFarm.getPendingRewards(alice.address);
    expect(rewardsAntes).to.be.gt(0);

    await tokenFarm.connect(alice).withdraw();

    // Recompensas aún deben estar disponibles
    const rewardsDespues = await tokenFarm.getPendingRewards(alice.address);
    expect(rewardsDespues).to.be.equal(rewardsAntes);

    // Usuario puede aún reclamarlas después del withdraw
    const dappAntes = await dappToken.balanceOf(alice.address);
    await tokenFarm.connect(alice).claimRewards();
    const dappDespues = await dappToken.balanceOf(alice.address);

    expect(dappDespues.sub(dappAntes)).to.equal(rewardsAntes);
  });
});
