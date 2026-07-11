import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { VaultPanel } from "../../components/dashboard/VaultPanel";
import { useWalletStore } from "../../store/wallet";

const refetchPositions = vi.fn();

vi.mock("../../hooks/useVaults", () => ({
  useVaults: () => ({
    data: {
      vaults: [
        {
          id: "meridian-usdc",
          protocol: "meridian",
          asset: "USDC",
          name: "Meridian",
          label: "USDC Vault",
          apy: 8,
          tvl: 10_000,
          userBalance: 0,
          riskLevel: "safe",
        },
      ],
      recommendedVaultId: "meridian-usdc",
    },
    isLoading: false,
  }),
}));

vi.mock("../../hooks/usePositions", () => ({
  usePositions: () => ({
    data: [],
    isError: true,
    refetch: refetchPositions,
  }),
}));

vi.mock("../../hooks/useVaultActions", () => ({
  useVaultActions: () => ({
    deposit: vi.fn(async () => true),
    withdraw: vi.fn(async () => true),
    isDepositing: false,
    isWithdrawing: false,
  }),
}));

vi.mock("../../hooks/useWalletConnect", () => ({
  useWalletConnect: () => ({
    handleConnect: vi.fn(),
    status: "idle",
  }),
}));

vi.mock("react-i18next", () => ({
  useTranslation: () => ({
    t: (key: string) => key,
    i18n: { language: "en" },
  }),
}));

beforeEach(() => {
  refetchPositions.mockClear();
  useWalletStore.setState({
    publicKey: "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5",
    connected: true,
    network: "testnet",
  });
});

describe("VaultPanel — position load error", () => {
  it("shows an error message with a retry button when positions fail to load", () => {
    render(<VaultPanel />);

    expect(screen.getByText("vaultPanel.positionsError")).toBeDefined();
    const retryButton = screen.getByText("common.retry");
    fireEvent.click(retryButton);
    expect(refetchPositions).toHaveBeenCalledTimes(1);
  });

  it("keeps the deposit tab usable while positions fail to load", () => {
    render(<VaultPanel />);

    // The deposit amount input and button are still present and become
    // enabled once an amount is entered, unaffected by the positions error.
    const amountInput = screen.getByPlaceholderText("0.00");
    fireEvent.change(amountInput, { target: { value: "10" } });

    const depositButton = screen
      .getByText("vaultPanel.deposit")
      .closest("button");
    expect(depositButton?.disabled).toBe(false);
  });
});
