import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { proxyModule } from "./ProxyModule";

const upgradeModule = buildModule("UpgradeModule", (m) => {
  const proxyAdminOwner = m.getAccount(0);

  const { proxyAdmin, proxy } = m.useModule(proxyModule);

  const froggyFriends = m.contract("froggyFriends");

  m.call(proxyAdmin, "upgradeAndCall", [proxy, froggyFriends], {
    from: proxyAdminOwner,
  });

  return { proxyAdmin, proxy };
});

const froggyFriendsModule = buildModule("FroggyFriendsUpgradeModule", (m) => {
  const { proxy } = m.useModule(upgradeModule);

  const froggyFriends = m.contractAt("FroggyFriends", proxy);

  return { froggyFriends };
});

export default froggyFriendsModule;