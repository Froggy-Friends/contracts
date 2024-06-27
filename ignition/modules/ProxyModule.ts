import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export const proxyModule = buildModule("ProxyModule", (m) => {
  const proxyAdminOwner = m.getAccount(0);

  const froggyFriends = m.contract("FroggyFriends");

  const proxy = m.contract("TransparentUpgradeableProxy", [
    froggyFriends,
    proxyAdminOwner,
    "0x",
  ]);

  const proxyAdminAddress = m.readEventArgument(
    proxy,
    "AdminChanged",
    "newAdmin"
  );

  const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress);

  return { proxyAdmin, proxy };
});

const froggyFriendsModule = buildModule("FroggyFriendsModule", (m) => {
  const { proxy, proxyAdmin } = m.useModule(proxyModule);

  const froggyFriends = m.contractAt("FroggyFriends", proxy);

  return { froggyFriends, proxy, proxyAdmin };
});

export default froggyFriendsModule;