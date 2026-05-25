# The four Yazi Kanagawa flavor specs, shared by modules/packages.nix (which
# exposes them as packages) and the yazi home-manager module (which installs
# them). `theme` names a table in lib.kanagawa.themes; uuids are stable.
[
  {
    name = "kanagawa-kris";
    title = "Kanagawa Kris";
    uuid = "592FC036-6BB7-4676-A2F5-2894D48C8E33";
    theme = "kris";
  }
  {
    name = "kanagawa-wave";
    title = "Kanagawa Wave";
    uuid = "9B8F6F76-5FA0-4B82-957A-C2D3E30C2A67";
    theme = "wave";
  }
  {
    name = "kanagawa-dragon";
    title = "Kanagawa Dragon";
    uuid = "07CF885C-2FC3-4A0B-8501-BAA5D3093BEA";
    theme = "dragon";
  }
  {
    name = "kanagawa-lotus";
    title = "Kanagawa Lotus";
    uuid = "CA13E094-E572-410B-979E-F25794DC716B";
    appearance = "light";
    theme = "lotus";
  }
]
