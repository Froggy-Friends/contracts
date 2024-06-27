import { minGasToTransfer, lzBlastEndpoint } from './../../utils/constants';
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("FroggyFriendsBlastModule", (m) => {
  const deployer = m.getAccount(0);

  const froggyFriends = m.contract("FroggyFriends", [minGasToTransfer, lzBlastEndpoint], { from: deployer });

  return { froggyFriends };
});