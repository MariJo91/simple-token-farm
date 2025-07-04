// SPDX-License-Identifier: MIT
// Desarrollado por María José Atencio
pragma solidity ^0.8.22; // Define la versión del compilador Solidity.

// Importamos los contratos de tokens ERC20 que representarán
// el token de recompensa (DappToken) y el token de liquidez (LPToken).
import "./DappToken.sol";
import "./LPToken.sol";

/**
 * @title Proportional Token Farm
 * @notice Una granja de staking donde las recompensas se distribuyen proporcionalmente al total de LP Tokens stakeados.
 * Permite a los usuarios depositar y retirar sus LP Tokens, y reclamar las recompensas generadas en Dapp Tokens.
 * @dev Este contrato implementa la lógica principal de la granja de rendimiento (yield farming),
 * calculando las recompensas en función del tiempo (número de bloques) y la proporción del staking de cada usuario.
 */
contract TokenFarm {
    // --- Variables de Estado ---

    // @dev Nombre de la granja, para una fácil identificación.
    string public name = "Proportional Token Farm";

    // @dev La dirección del propietario del contrato. El propietario tiene permisos especiales,
    // como la capacidad de iniciar una distribución global de recompensas. Se establece una vez
    // durante el despliegue y no puede cambiar (inmutable).
    address public immutable owner;

    // @dev Referencias a las instancias de los contratos DappToken y LPToken.
    // Usaremos estas referencias para interactuar con las funciones de los tokens (ej., transferir, mintear).
    DappToken public dappToken;
    LPToken public lpToken;

    // @dev Cantidad de DAPP Tokens que la farm genera como recompensa por bloque.
    // Este es el "factor" de recompensa que se distribuye entre todos los stakers.
    // 1e18 representa 1 token DAPP completo, asumiendo que DappToken tiene 18 decimales.
    uint256 public constant REWARD_PER_BLOCK = 1e18; // En un bonus futuro, este valor podría ser variable.

    // @dev El balance total de todos los LP Tokens que están actualmente en staking dentro de este contrato.
    // Es crucial para calcular la proporción de staking de cada usuario.
    uint256 public totalStakingBalance;

    // --- Bonus 2: Estructura para la Información del Usuario (`StakeInfo`) ---
    // @dev Definimos una estructura para agrupar toda la información relevante de staking de un solo usuario.
    // Esto mejora la legibilidad del código y la eficiencia del almacenamiento al reducir el número de mappings.
    struct StakeInfo {
        uint256 stakingBalance;       // Cantidad de LP Tokens que el usuario tiene actualmente en staking.
        uint256 lastRewardCheckpoint; // El número de bloque en el que se calcularon o actualizaron por última vez las recompensas del usuario.
        uint256 pendingRewards;       // La cantidad de Dapp Tokens que el usuario ha acumulado y está pendiente de reclamar.
        bool hasStaked;               // Un flag que indica si el usuario ha depositado LP Tokens alguna vez (útil para agregarlo una sola vez al array `stakers`).
        bool isStaking;               // Un flag que indica si el usuario tiene LP Tokens activos en staking en este momento.
    }

    // @dev Mapping que asocia una dirección de usuario con su estructura `StakeInfo` completa.
    mapping(address => StakeInfo) public userStake;

    // @dev Un array que almacena todas las direcciones de los usuarios que han depositado LP Tokens al menos una vez.
    // Se utiliza para iterar sobre todos los stakers cuando el propietario distribuye recompensas.
    address[] public stakers;

    // --- Modificadores (Bonus 1) ---
    // Los modificadores son fragmentos de código reutilizables que se pueden adjuntar a funciones
    // para imponer pre-condiciones, como control de acceso.

    /// @dev Modificador que restringe la ejecución de una función solo al propietario del contrato.
    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el owner puede ejecutar esta funcion");
        _; // El underscore indica dónde se insertará el código de la función.
    }

    /// @dev Modificador que restringe la ejecución de una función solo a un usuario que actualmente tiene LP Tokens en staking.
    modifier onlyStaker() {
        require(userStake[msg.sender].isStaking, "Debes estar haciendo staking para realizar esta accion");
        _; // El underscore indica dónde se insertará el código de la función.
    }

    // --- Eventos ---
    // Los eventos son fundamentales para la comunicación on-chain y off-chain, permitiendo que las aplicaciones
    // externas (front-ends, exploradores de bloques) reaccionen a los cambios de estado del contrato.

    /// @dev Emitido cuando un usuario deposita LP Tokens en la farm.
    /// @param user La dirección del usuario que realizó el depósito.
    /// @param amount La cantidad de LP Tokens depositados.
    event Deposit(address indexed user, uint256 amount);

    /// @dev Emitido cuando un usuario retira sus LP Tokens de la farm.
    /// @param user La dirección del usuario que realizó el retiro.
    /// @param amount La cantidad de LP Tokens retirados.
    event Withdraw(address indexed user, uint256 amount);

    /// @dev Emitido cuando un usuario reclama sus recompensas de Dapp Tokens.
    /// @param user La dirección del usuario que reclamó las recompensas.
    /// @param amount La cantidad de Dapp Tokens reclamados.
    event RewardsClaimed(address indexed user, uint256 amount);

    /// @dev Emitido cuando el propietario del contrato activa la distribución de recompensas para todos los stakers.
    /// @param blockNumber El número de bloque en el que se inició la distribución.
    // El evento original incluía `totalDistributed`, pero como la función `distributeRewardsAll` solo acumula
    // y no transfiere, su valor sería 0 aquí. Por simplicidad, lo retiramos si no va a ser usado.
    event RewardsDistributedAll(uint256 blockNumber);


    // --- Constructor ---

    /// @notice Constructor del contrato TokenFarm.
    /// @dev Se ejecuta una sola vez al desplegar el contrato. Inicializa las referencias a los contratos
    /// DappToken y LPToken y establece la dirección del desplegador como el propietario.
    /// @param _dappToken La dirección del contrato DAppToken ya desplegado.
    /// @param _lpToken La dirección del contrato LPToken ya desplegado.
    constructor(DappToken _dappToken, LPToken _lpToken) {
        dappToken = _dappToken; // Asignamos la dirección del DappToken.
        lpToken = _lpToken;     // Asignamos la dirección del LPToken.
        owner = msg.sender;     // El deployer de este contrato se convierte en el propietario.
    }

    // --- Funciones de la Farm ---

    /**
     * @notice Permite a un usuario depositar una cantidad de LP Tokens para comenzar a hacer staking y ganar recompensas.
     * @dev Antes de depositar, el usuario debe haber aprobado (`approve()`) que este contrato
     * pueda transferir sus LP Tokens desde su cuenta.
     * Al depositar, se recalculan las recompensas pendientes del usuario para asegurar
     * que no se pierdan recompensas de bloques anteriores.
     * @param _amount La cantidad de LP Tokens que el usuario desea depositar.
     */
    function deposit(uint256 _amount) external {
        // Validamos que la cantidad a depositar sea mayor que cero.
        require(_amount > 0, "Debes depositar un monto mayor a 0");

        // Si el usuario ya está haciendo staking, actualizamos sus recompensas pendientes
        // antes de procesar el nuevo depósito. Esto asegura la exactitud de las recompensas.
        if (userStake[msg.sender].isStaking) {
            distributeRewards(msg.sender);
        }

        // Transferimos los LP Tokens desde la cuenta del usuario a este contrato de la farm.
        // Esto requiere una aprobación previa del usuario en el contrato LPToken.
        lpToken.transferFrom(msg.sender, address(this), _amount);

        // Actualizamos el balance de staking del usuario en su estructura `userStake`.
        userStake[msg.sender].stakingBalance += _amount;
        // Incrementamos el balance total de staking de la farm.
        totalStakingBalance += _amount;

        // Si es la primera vez que este usuario deposita, lo añadimos al array `stakers`.
        // Esto es necesario para que el propietario pueda iterar sobre todos los stakers.
        if (!userStake[msg.sender].hasStaked) {
            stakers.push(msg.sender);
            userStake[msg.sender].hasStaked = true;
        }

        // Marcamos al usuario como alguien que actualmente tiene staking activo.
        userStake[msg.sender].isStaking = true;

        // Si es el primer depósito del usuario, inicializamos su checkpoint al bloque actual.
        // Esto asegura que el cálculo de recompensas comience desde el momento del primer stake.
        if (userStake[msg.sender].lastRewardCheckpoint == 0) {
            userStake[msg.sender].lastRewardCheckpoint = block.number;
        }

        // Emitimos un evento para registrar el depósito en la blockchain.
        emit Deposit(msg.sender, _amount);
    }

    /**
     * @notice Permite a un usuario retirar todos sus LP Tokens que tiene en staking.
     * @dev Al retirar, se recalculan las recompensas pendientes del usuario. Los LP Tokens
     * se transfieren de vuelta al usuario, y su balance de staking se restablece a cero.
     * Las recompensas pendientes permanecen disponibles para ser reclamadas por separado.
     * Utiliza el modificador `onlyStaker` para asegurar que solo los stakers activos puedan llamar a esta función.
     */
    function withdraw() external onlyStaker {
        // Obtenemos la cantidad actual de LP Tokens que el usuario tiene en staking.
        uint256 balance = userStake[msg.sender].stakingBalance;
        // Validamos que el usuario realmente tenga tokens para retirar.
        require(balance > 0, "Tu balance de staking es 0");

        // Calculamos y actualizamos las recompensas pendientes ANTES de restablecer el balance de staking.
        // Esto garantiza que el usuario reciba recompensas hasta el momento exacto del retiro.
        distributeRewards(msg.sender);

        // Restablecemos el balance de staking del usuario a cero.
        userStake[msg.sender].stakingBalance = 0;
        // Marcamos al usuario como no activo en staking.
        userStake[msg.sender].isStaking = false;
        // Reducimos el balance total de staking de la farm.
        totalStakingBalance -= balance;

        // Transferimos los LP Tokens de vuelta a la cuenta del usuario.
        lpToken.transfer(msg.sender, balance);

        // Emitimos un evento para registrar el retiro.
        emit Withdraw(msg.sender, balance);
    }

    /**
     * @notice Permite a un usuario reclamar las recompensas de Dapp Tokens que ha acumulado.
     * @dev Las recompensas pendientes se mintean y se transfieren a la cuenta del usuario.
     * El balance de recompensas pendientes del usuario se restablece a cero después del reclamo.
     * Utiliza el modificador `onlyStaker` para asegurar que solo los stakers activos puedan llamar a esta función.
     */
    function claimRewards() external onlyStaker {
        // Aseguramos que las recompensas del usuario estén completamente actualizadas antes de reclamar.
        distributeRewards(msg.sender);

        // Obtenemos la cantidad de recompensas que el usuario tiene pendientes.
        uint256 reward = userStake[msg.sender].pendingRewards;
        // Validamos que haya recompensas pendientes para reclamar.
        require(reward > 0, "No tienes recompensas pendientes");

        // Restablecemos las recompensas pendientes del usuario a cero, ya que se van a transferir.
        userStake[msg.sender].pendingRewards = 0;
        // Minteamos y transferimos los Dapp Tokens de recompensa a la cuenta del usuario.
        // Importante: El contrato TokenFarm debe ser el 'owner' o tener el rol de 'MINTER'
        // en el contrato DappToken para que esta operación sea exitosa.
        dappToken.mint(msg.sender, reward);

        // Emitimos un evento para registrar el reclamo de recompensas.
        emit RewardsClaimed(msg.sender, reward);
    }

    /**
     * @notice Permite al propietario de la plataforma activar el cálculo y acumulación
     * de recompensas para TODOS los usuarios que actualmente tienen staking.
     * @dev Esta función itera sobre el array `stakers` y llama a `distributeRewards`
     * para cada usuario activo. No transfiere tokens, solo actualiza los balances de `pendingRewards`.
     * Utiliza el modificador `onlyOwner` para restringir el acceso.
     */
    function distributeRewardsAll() external onlyOwner {
        // Recorremos el array de todas las direcciones de usuarios que han stakeado alguna vez.
        for (uint256 i = 0; i < stakers.length; i++) {
            address user = stakers[i]; // Obtenemos la dirección del staker.

            // Solo actualizamos las recompensas para los usuarios que actualmente tienen LP Tokens en staking.
            // Con la estructura `StakeInfo`, accedemos a `isStaking` a través de `userStake[user]`.
            if (userStake[user].isStaking) {
                // Llamamos a la función privada para calcular y acumular las recompensas.
                distributeRewards(user);
                // Las recompensas se acumulan en `userStake[user].pendingRewards`,
                // no se transfieren en esta función.
            }
        }
        // Emitimos un evento para indicar que la distribución general ha ocurrido.
        // El `totalDistributed` se ha eliminado del evento porque no se calcula ni se transfiere un total aquí.
        emit RewardsDistributedAll(block.number);
    }

    /**
     * @notice Calcula y acumula las recompensas de Dapp Tokens para un beneficiario específico.
     * @dev Esta función es privada y se llama internamente desde otras funciones (deposit, withdraw, claimRewards, distributeRewardsAll).
     * Las recompensas se calculan proporcionalmente al balance de staking del usuario en relación con el `totalStakingBalance`,
     * y al número de bloques transcurridos desde el último cálculo.
     *
     * Funcionamiento detallado:
     * 1. Verifica si el usuario tiene un balance de staking y si hay un `totalStakingBalance` en la farm.
     * 2. Calcula la cantidad de bloques transcurridos (`blocksPassed`) desde `lastRewardCheckpoint` del usuario hasta el `block.number` actual.
     * 3. Calcula la "participación" del usuario (`share`) como `stakingBalance[beneficiary] / totalStakingBalance`.
     * 4. La `reward` para el usuario se calcula como `REWARD_PER_BLOCK * blocksPassed * share`.
     * 5. Esta `reward` calculada se añade a `userStake[beneficiary].pendingRewards`.
     * 6. El `lastRewardCheckpoint` del usuario se actualiza al `block.number` actual.
     *
     * Nota: Este sistema asegura que las recompensas se distribuyan proporcionalmente y de manera justa
     * entre todos los usuarios en función de su contribución al staking total, por cada bloque que pasa.
     */
    function distributeRewards(address beneficiary) private {
        // Solo procedemos si el usuario tiene LP Tokens stakeados y si hay un total de staking en la farm.
        // También verificamos que el bloque actual sea posterior al último checkpoint para evitar cálculos duplicados.
        if (userStake[beneficiary].stakingBalance > 0 && totalStakingBalance > 0 && block.number > userStake[beneficiary].lastRewardCheckpoint) {
            // Calculamos cuántos bloques han pasado desde la última vez que se actualizaron las recompensas de este usuario.
            uint256 blocksPassed = block.number - userStake[beneficiary].lastRewardCheckpoint;

            // Calculamos la recompensa para el usuario. Para evitar la pérdida de precisión por la división
            // antes de la multiplicación, multiplicamos primero y luego dividimos.
            // (Balance del usuario * Recompensa por bloque * Bloques transcurridos) / Balance total de la farm
            uint256 reward = (userStake[beneficiary].stakingBalance * REWARD_PER_BLOCK * blocksPassed) / totalStakingBalance;

            // Agregamos la recompensa calculada a las recompensas pendientes del usuario.
            userStake[beneficiary].pendingRewards += reward;
        }

        // Siempre actualizamos el checkpoint del usuario al bloque actual. Esto es crucial
        // para que los futuros cálculos de recompensas comiencen desde este bloque,
        // incluso si no se acumularon recompensas en esta llamada (ej., si blocksPassed era 0).
        userStake[beneficiary].lastRewardCheckpoint = block.number;
    }

    // --- Funciones de Consulta (View Functions) ---
    // Estas funciones no modifican el estado de la blockchain y son "gratuitas" de llamar.

    /// @notice Retorna la cantidad actual de recompensas de Dapp Tokens pendientes para un usuario dado.
    /// @dev Nota: Esta función `view` no recalcula las recompensas en tiempo real. Retorna
    /// el último valor acumulado. Para un valor completamente actualizado, el usuario tendría que
    /// interactuar con una función que llame a `distributeRewards` (ej., deposit, withdraw, claimRewards).
    /// @param _user La dirección del usuario cuya información de recompensas se desea consultar.
    /// @return La cantidad de Dapp Tokens que el usuario tiene pendientes de reclamar.
    function getPendingRewards(address _user) public view returns (uint256) {
        return userStake[_user].pendingRewards;
    }

    /// @notice Retorna el balance actual de LP Tokens que un usuario específico tiene en staking.
    /// @param _user La dirección del usuario cuyo balance de staking se desea consultar.
    /// @return La cantidad de LP Tokens que el usuario tiene en staking.
    function getStakingBalance(address _user) public view returns (uint256) {
        return userStake[_user].stakingBalance;
    }
}