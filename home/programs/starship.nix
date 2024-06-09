{ pkgs, ... }:

{
  # starship - an customizable prompt for any shell
  programs.starship = {
    enable = true;
    settings = {
      # add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      # line_break.disabled = true;
    };
  };
}
