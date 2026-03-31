DeadSwitch.sol: 

-> Who owns this vault, how money will be trnasacted, state of vault
-> Owner last checkIn
-> When the current state started
-> Timing config( when will be check In, warning period, grace period warning period) 
-> which tokens are currently in the vault and how tokens are being distributed or not 
-> Whether vault is initlised or not yet  

owner              → address  → 20 bytes
state              → enum     → 1 byte (5 values fits in uint8)
lastCheckIn        → timestamp → uint48 = 6 bytes (max year 8,919,531)
stateChangedAt     → timestamp → uint48 = 6 bytes

checkInInterval    → duration  → uint48 = 6 bytes (max ~8900 years)
warningPeriod      → duration  → uint48 = 6 bytes
gracePeriod        → duration  → uint48 = 6 bytes

yieldAdapter       → address  → 20 bytes
willRegistry       → address  → 20 bytes
streamEngine       → address  → 20 bytes

supportedTokens    → address[] → 32 bytes (dynamic array pointer)
tokenExists        → mapping   → 32 bytes (slot reserved, data elsewhere)  

ReentrancyGuard, it adds another storage slot for the lock variable. 
Transient storage reentrancy guard (available in Solidity 0.8.28+) which uses TSTORE/TLOAD instead of SSTORE/SLOAD, much cheaper because transient storage is cleared after each transaction 


