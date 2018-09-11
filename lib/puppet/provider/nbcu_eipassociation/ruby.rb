require 'aws-sdk'
require 'json'
require 'net/http'

Puppet::Type.type(:org_eipassociation).provide(:ruby) do
  def exists?
    has_eip_associated?
  end

  def create
    if has_eip_associated? and !allocation_match?
      disassociate_eip
    end
    associate_eip
  end

  def destroy
    if has_eip_associated? and allocation_match?
      disassociate_eip
    end
  end

  private
  def ec2
    _ec2 ||= Aws::EC2::Resource.new
  end
  
  def nstance_id
    _instance_id ||= Net::HTTP.get('169.254.169.254', '/latest/meta-data/instance-id')
  end

  def instance
    _instance ||= ec2.instance(instance_id)
  end

  def eips
    if defined? _eips
      _eips
    else
      @allocation_id = @resource[:allocation_id]
      _eips = {}
      params = JSON.parse('')
      for @address in ec2.client.describe_addresses({
        filters: [{
          name: 'domain',
          values: ['vpc']
        }]
      }).addresses.each
          _eips[@address.public_ip] = { allocation_id: @address.allocation_id,
                                        association_id: @address.association_id }
      end
    end
    _eips
  end
 
  def has_eip_associated?
    eips.keys.include? instance.public_ip_address
  end

  def allocation_match?
    eips[instance.public_ip_address][:allocation_id] == resource[:allocation_id]
  end

  def associate_eip
    params = JSON.parse('{"allocation_id":"' + @resource[:allocation_id] + '","instance_id":"' + instance_id + '"}')
    @resp = ec2.client.associate_address(params)
  end

  def disassociate_eip
    params = JSON.parse('{"association_id" : "' + eips[instance.public_ip_address][:association_id] + '"}')
    @resp = ec2.client.disassociate_address(params)
  end
end
