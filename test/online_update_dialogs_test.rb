#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "OnlineUpdateDialogs"
Yast.import "Pkg"
Yast.import "UI"

DEFAULT_PATCH = {
    "status" => :selected,
    "name" => "patch_#{$patch_id}",
    "reboot_needed" => false,
    "description" => "...",
    "arch" => "noarch",
}

def patch(args = {})
  $patch_id ||= 0
  $patch_id += 1
  DEFAULT_PATCH.merge(args)
end

# Two patches have "reboot_needed" => true
PATCHES = Array.new(2){ patch("reboot_needed" => true) } + Array.new(2){ patch }

# All patches are "reboot_needed" => false
PATCHES_WITHOUT_REBOOTING = Array.new(4){ patch }

describe "OnlineUpdateDialogs" do
  before(:each) do
    Yast::Pkg.stub(:ResolvableProperties).and_return(PATCHES)
    Yast::Pkg.stub(:ResolvableNeutral).and_return(true)
    Yast::Pkg.stub(:PkgSolve).and_return(true)
  end

  describe "#patches_needing_reboot" do
    it "returns list of selected patches that need rebooting" do
      expect(Yast::OnlineUpdateDialogs.patches_needing_reboot.size).to eq 2
    end
  end

  describe "#formatted_rebooting_patches" do
    it "returns list of strings describing patch in HTML when :use_html is set" do
      patches = Yast::OnlineUpdateDialogs.formatted_rebooting_patches(:use_html => true)
      expect(patches.size).to eq 2
      expect(patches[0]).to match(/</)
      expect(patches[0]).to match(/>/)
    end

    it "returns list of strings describing patch in plain text when :use_html is not set" do
      patches = Yast::OnlineUpdateDialogs.formatted_rebooting_patches(:use_html => false)
      expect(patches.size).to eq 2
      expect(patches[0]).not_to match(/</)
      expect(patches[0]).not_to match(/>/)
    end
  end

  describe "#rebooting_patches_dialog" do
    it "returns dialog layout" do
      expect(Yast::OnlineUpdateDialogs.rebooting_patches_dialog).not_to eq nil
    end
  end

  describe "#confirm_rebooting_patches" do
    before(:each) do
      Yast::UI.stub(:OpenDialog).and_return(true)
      Yast::UI.stub(:CloseDialog).and_return(true)
    end

    it "returns true if user decides to continue" do
      Yast::UI.stub(:UserInput).and_return(Yast::OnlineUpdateDialogsClass::RebootingPatches::Buttons::CONTINUE)
      expect(Yast::OnlineUpdateDialogs.confirm_rebooting_patches).to be_true
    end

    it "returns false if user decides to go back" do
      Yast::UI.stub(:UserInput).and_return(Yast::OnlineUpdateDialogsClass::RebootingPatches::Buttons::BACK)
      expect(Yast::OnlineUpdateDialogs.confirm_rebooting_patches).to be_false
    end

    it "returns true if user decides to skip rebooting patches and they are automatically unselected" do
      # At first, there are some rebooting patches selected, later there are none
      Yast::Pkg.stub(:ResolvableProperties).and_return(PATCHES, PATCHES_WITHOUT_REBOOTING)
      Yast::UI.stub(:UserInput).and_return(Yast::OnlineUpdateDialogsClass::RebootingPatches::Buttons::SKIP)
      expect(Yast::OnlineUpdateDialogs.confirm_rebooting_patches).to be_true, "Selected patches: #{Yast::Pkg.ResolvableProperties()}"
    end

    it "returns false if user decides to skip rebooting patches but they are not automatically unselected" do
      # At first, there are some rebooting patches selected, later there still the same ones
      Yast::Pkg.stub(:ResolvableProperties).and_return(PATCHES)
      Yast::UI.stub(:UserInput).and_return(Yast::OnlineUpdateDialogsClass::RebootingPatches::Buttons::SKIP)
      expect(Yast::OnlineUpdateDialogs.confirm_rebooting_patches).to be_false, "Selected patches: #{Yast::Pkg.ResolvableProperties()}"
    end

    it "returns false if user decides to skip rebooting patches but there are solver errors preset" do
      # At first, there are some rebooting patches selected, later there are none
      Yast::Pkg.stub(:ResolvableProperties).and_return(PATCHES, PATCHES_WITHOUT_REBOOTING)
      Yast::UI.stub(:UserInput).and_return(Yast::OnlineUpdateDialogsClass::RebootingPatches::Buttons::SKIP)
      Yast::Pkg.stub(:PkgSolve).and_return(false)
      expect(Yast::OnlineUpdateDialogs.confirm_rebooting_patches).to be_false, "Selected patches: #{Yast::Pkg.ResolvableProperties()}"
    end

    it "raises an exception if UI returns unexpected return value" do
      Yast::UI.stub(:UserInput).and_return(:unknown_user_input)
      expect { Yast::OnlineUpdateDialogs.confirm_rebooting_patches }.to raise_error
    end
  end
end
