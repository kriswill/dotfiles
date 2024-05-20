{
  programs.firefox = {
    enable = true;
    profiles.k = {
      userChrome = ''
        /* Hide tab bar. Used with Sidebery */
        #TabsToolbar {
          visibility: collapse !important;
        }
      '';
    };
  };
}
