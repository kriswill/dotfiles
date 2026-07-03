{
  # Declarative Chromium managed-policy file. Helium (unbranded Chromium fork)
  # reads /etc/chromium/policies/managed/*.json. environment.etc writes it
  # root-owned (required, or Chromium ignores it) and is independent of
  # programs.chromium.enable (false). Standard Chromium policy keys apply;
  # Helium's de-Googled HopProvider is a separate policy source, so these still
  # take effect. Verify what loaded at chrome://policy after a rebuild + full
  # Helium restart.
  flake.modules.nixos.helium = _: {
    environment.etc."chromium/policies/managed/helium.json".text = builtins.toJSON {
      # --- Privacy baseline (pure enforcement) ---
      MetricsReportingEnabled = false;
      BackgroundModeEnabled = false;
      SafeBrowsingExtendedReportingEnabled = false;
      UrlKeyedAnonymizedDataCollectionEnabled = false;

      # --- Startup / homepage (matches current "restore last session") ---
      RestoreOnStartup = 1; # 1 = continue where you left off
      ShowHomeButton = true;
      # HomepageLocation = "https://…";   # optional — uncomment to pin a homepage
      # HomepageIsNewTabPage = true;

      # --- Default search (TUNABLE — defaults to DuckDuckGo; none set currently) ---
      DefaultSearchProviderEnabled = true;
      DefaultSearchProviderName = "DuckDuckGo";
      DefaultSearchProviderSearchURL = "https://duckduckgo.com/?q={searchTerms}";
      DefaultSearchProviderSuggestURL = "https://duckduckgo.com/ac/?q={searchTerms}&type=list";

      # --- Force-install extensions (CWS update URL) ---
      # uBlock Origin is built into Helium (helium://extensions/?id=blockjmkbacgjkknlgpkjjiijinjdanf),
      # so it is NOT listed here — Helium ships and updates it itself.
      ExtensionInstallForcelist = [
        # Dark Reader — https://chromewebstore.google.com/detail/dark-reader/eimadpbcbfnmbkopoojfekhnkhdbieeh
        "eimadpbcbfnmbkopoojfekhnkhdbieeh;https://clients2.google.com/service/update2/crx"
        # 1Password — https://chromewebstore.google.com/detail/aeblfdkhhhdcdjpifhhbdiojplfjncoa
        "aeblfdkhhhdcdjpifhhbdiojplfjncoa;https://clients2.google.com/service/update2/crx"
      ];
    };
  };
}
