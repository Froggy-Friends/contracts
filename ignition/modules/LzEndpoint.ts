import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const lzEndpointModule = buildModule("LzEndpointModule", (m) => {
  const owner = m.getAccount(0);
  const chainId = m.getParameter("chainId", 1);
  const lzEndpointMock = m.contract("LzEndpointMock", [chainId], {
    from: owner,
  });

  return { lzEndpointMock };
});

export default lzEndpointModule;
