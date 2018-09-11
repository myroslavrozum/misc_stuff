require "resolv"

Puppet::Type.newtype(:org_eipassociation) do
  @doc <<-EOT
  Associates existing, unallocated EIP to the instance:
    eip_association { eipname:
      ensure        => present,
      allocation_id => 'eipalloc-asdfghj',
    }

  EOT

  ensurable
    
  newparam(:elastic_ip_address, :namevar => true) do
    desc "EIP to associate"
    validate do |value|
      unless value =~ Resolv::IPv4::Regex
        raise ArgumentError "#{value} 'elastic_ip' must be a valid IPv4 address"
      end
    end
  end

  newparam(:allocation_id) do
    desc "EIP allocation ID to associate"
    validate do |value|
      unless value =~ /^eipalloc-\w+/
        raise ArgumentError "#{value} is not valid EIP allocation ID"
      end
    end
  end

  validate do
    unless self[:allocation_id] or self[:elstic_ip_address]
      raise(Puppet::Error, "Allocation ID or IP address are required attributes")
    end
  end
end
