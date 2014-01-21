#! /usr/bin/env ruby

require 'spec_helper'
require 'yaml'
require 'puppet/util/network_device/dell_iom/device'
require 'puppet/provider/mxl_vlan/dell_iom'

describe "Integration test for mxl vlan" do

  provider_class = Puppet::Type.type(:mxl_vlan).provider(:dell_iom)

  before do

    @device = provider_class.device("telnet://root:calvin@10.94.147.190/")
  end

  let :mxl_vlan do
    Puppet::Type.type(:mxl_vlan).new(
    :name  => '190',
    :desc      => 'test desc',
    :vlan_name => 'test name',
    :ensure => 'present'
    )
  end

  context 'when configuring vlan' do
    it "should configure vlan" do
      preresult = provider_class.lookup(@device, mxl_vlan[:name])
      @device.switch.vlan(mxl_vlan[:name]).update(preresult,{:ensure => mxl_vlan[:ensure], :desc => mxl_vlan[:desc], :vlan_name => mxl_vlan[:vlan_name]})
      postresult = provider_class.lookup(@device, mxl_vlan[:name])
      pp "postresult1 = #{postresult}"
      postresult.should include({:desc => mxl_vlan[:desc], :vlan_name => mxl_vlan[:vlan_name]})
      pp "postresult2 = #{postresult}"

    end
  end

end

