require 'spec_helper'
require 'puppet_x/puppetlabs/dockerimagebuilder'

describe PuppetX::Puppetlabs::DockerImageBuilder do
  let(:from) { 'debian:8' }
  let(:image_name) { 'puppet/sample' }
  let(:manifest) { Tempfile.new('manifest.pp') }
  let(:builder) { PuppetX::Puppetlabs::DockerImageBuilder.new(manifest.path, args) }
  let(:context) { builder.context }

  context 'without any arguments' do
    let(:args) { {} }
    it 'should raise an error about missing operating system details' do
      expect { builder.context }.to raise_exception(PuppetX::Puppetlabs::InvalidContextError, /currently only supports/)
    end
  end

  context 'with minimal arguments' do
    let(:args) do
      {
        from: from,
        image_name: image_name,
      }
    end
    it 'should not raise an error' do
      expect { context }.not_to raise_error
    end
    context 'should produce a context with' do
      it 'the original from value' do
        expect(context).to include(from: args[:from])
      end
      it 'the original image_name value' do
        expect(context).to include(image_name: args[:image_name])
      end
      it 'an operating sytem inferred' do
        expect(context).to include(os: 'debian', os_version: '8')
      end
      it 'paths for Puppet binaries calculated' do
        expect(context).to include(:puppet_path, :gem_path, :r10k_path)
      end
      it 'the OS codename in an environment variable' do
        expect(context[:environment]).to include(codename: 'jessie')
      end
    end
    it '#dockerfile should return a Dockerfile object' do
      expect(builder.dockerfile).to be_a(PuppetX::Puppetlabs::Dockerfile)
    end
    it 'should use docker build as the default build command' do
      expect(builder.send(:build_command)).to start_with('docker')
    end
  end

  context 'with a Puppetfile provided' do
    let(:puppetfile) { Tempfile.new('Puppetfile') }
    let(:args) do
      {
        from: from,
        image_name: image_name,
        puppetfile: puppetfile.path,
      }
    end
    it 'should not raise an error' do
      expect { context }.not_to raise_error
    end
    it 'should produce a context which enables the puppetfile options' do
      expect(context).to include(use_puppetfile: true)
    end
  end

  context 'with a hiera configuration provided' do
    let(:hieraconfig) { Tempfile.new('hiera.yaml') }
    let(:hieradata) { Dir.mktmpdir('hieradata') }
    let(:args) do
      {
        from: from,
        image_name: image_name,
        hiera_config: hieraconfig.path,
        hiera_data: hieradata,
      }
    end
    it 'should not raise an error' do
      expect { context }.not_to raise_error
    end
    it 'should produce a context which enables the hiera options' do
      expect(context).to include(use_hiera: true)
    end
  end

  context 'with an alternative operating system' do
    let(:args) do
      {
        from: 'alpine:3.4',
        image_name: image_name,
      }
    end
    context 'should produce a context with' do
      it 'an operating sytem inferred' do
        expect(context).to include(os: 'alpine', os_version: '3.4')
      end
      it 'paths for Puppet binaries calculated' do
        expect(context).to include(:puppet_path, :gem_path, :r10k_path)
      end
      it 'the facter and puppet version in an environment variable' do
        expect(context[:environment]).to include(:facter_version, :puppet_version)
      end
    end
  end

  context 'with an alternative build tool specified' do
    let(:args) do
      {
        from: from,
        image_name: image_name,
        rocker: true,
      }
    end
    it 'should use rocker build rather than the default' do
      expect(builder.send(:build_command)).to start_with('rocker')
    end
  end

  context 'with a config file used for providing input' do
    let(:configfile) do
      file = Tempfile.new('hiera.yaml')
      file.write <<-EOF
---
from: #{from}
image_name: #{image_name}
      EOF
      file.close
      file
    end
    let(:args) { { config_file: configfile.path } }
    it 'should not raise an error' do
      expect { context }.not_to raise_error
    end
    it 'the from value from the config file' do
      expect(context).to include(from: from)
    end
    it 'the image_name value from the config file' do
      expect(context).to include(image_name: image_name)
    end
    context 'do' do
      let(:new_image_name) { 'puppet/different' }
      let(:args) do
        {
          config_file: configfile.path,
          image_name: new_image_name,
        }
      end
      it 'the image_name value to have been overriden' do
        expect(context).to include(image_name: new_image_name)
      end
    end
  end

  context 'with an invalid config file used for providing input' do
    let(:configfile) do
      file = Tempfile.new('hiera.yaml')
      file.write <<-EOF
-
invalid
      EOF
      file.close
      file
    end
    let(:args) do
      {
        config_file: configfile.path
      }
    end
    it 'should raise a suitable error' do
      expect { context }.to raise_exception(PuppetX::Puppetlabs::InvalidContextError, /valid YAML/)
    end
  end

  os_codenames = {
    ubuntu: {
      '16.04' => 'xenial',
      '14.04' => 'trusty',
      '12.04' => 'precise',
    },
    debian: {
      '8' => 'jessie',
      '7' => 'wheezy',
    }
  }
  os_codenames.each do |os, hash|
    hash.each do |version, codename|
      context "when inheriting from #{os}:#{version}" do
        let(:args) do
          {
            from: "#{os}:#{version}",
            image_name: image_name,
          }
        end
        it "the codename should be #{codename}" do
          expect(context[:environment]).to include(codename: codename)
        end
      end
    end
  end
end