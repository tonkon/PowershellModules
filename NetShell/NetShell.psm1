###############################################################################################################################################################
#                                                             C# Enumerations and class extensions                                                            #
###############################################################################################################################################################

Add-Type @"
  using System;
  using System.Net;

  namespace Dhcp {
  
    // An enumeration for the request type.
  
    public enum RequestType : byte {
      Discover = 1,
      Offer = 2,
      Request = 3,
      Decline = 4,
      Ack = 5,
      NAck = 6,
      Release = 7
    }
  }

  namespace Extended {
  
    // Extended System.IO.BinaryReader class implementing overloads for ReadUInt16/32/64 to support endian order selection. 
    // Implemented Peek and added simple IP address return values
  
    public class BinaryReader : System.IO.BinaryReader {
      public BinaryReader(System.IO.Stream BaseStream) : base(BaseStream) { }
      
      public UInt16 ReadUInt16(Boolean IsBigEndian) {
        return (UInt16)((base.ReadByte() << 8) | base.ReadByte());
      }

      public UInt32 ReadUInt32(Boolean IsBigEndian) {
        return (UInt32)(
          (base.ReadByte() << 24) |
          (base.ReadByte() << 16) |
          (base.ReadByte() << 8) |
          base.ReadByte());
      }

      public UInt64 ReadUInt64(Boolean IsBigEndian) {
        return (UInt64)(
          (base.ReadByte() << 56) |
          (base.ReadByte() << 48) |
          (base.ReadByte() << 40) |
          (base.ReadByte() << 32) |
          (base.ReadByte() << 24) |
          (base.ReadByte() << 16) |
          (base.ReadByte() << 8) |
          base.ReadByte());
      }

      public Byte PeekByte() {
        Byte Value = base.ReadByte();
        base.BaseStream.Seek(-1, System.IO.SeekOrigin.Current);
        return Value;
      }

      public IPAddress ReadIPAddress() {
        return IPAddress.Parse(
          String.Format("{0}.{1}.{2}.{3}",
            base.ReadByte(),
            base.ReadByte(),
            base.ReadByte(),
            base.ReadByte()));
      }

      public IPAddress ReadIPv6Address() {
        return IPAddress.Parse(
          String.Format("{0:X}:{1:X}:{2:X}:{3:X}:{4:X}:{5:X}:{6:X}:{7:X}",
            this.ReadUInt16(true),
            this.ReadUInt16(true),
            this.ReadUInt16(true),
            this.ReadUInt16(true),
            this.ReadUInt16(true),
            this.ReadUInt16(true),
            this.ReadUInt16(true),
            this.ReadUInt16(true)));
      }
    }
  } 
"@

###############################################################################################################################################################
#                                                                         Subnet Math                                                                         #
###############################################################################################################################################################

Function ConvertTo-HexIP {
  <#
    .Synopsis
      Converts a dotted decimal IP address into a hexadecimal string.
    .Description
      ConvertTo-HexIP takes a dotted decimal IP and returns a single hexadecimal string value.
    .Parameter IPAddress
      An IP Address to convert.
  #>
 
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
    [Net.IPAddress]$IPAddress
  )
 
  Process {
    "$($IPAddress.GetAddressBytes() | ForEach-Object { '{0:x2}' -f $_ })" -Replace '\s'
  }
}

Function ConvertFrom-HexIP {
  <#
    .Synopsis
      Converts a hexadecimal IP address into a dotted decimal string.
    .Description
      ConvertFrom-HexIP takes a hexadecimal string and returns a dotted decimal IP address.
    .Parameter IPAddress
      An IP Address to convert.
  #>
 
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
    [ValidatePattern('^[0-9a-f]{8}$')]
    [String]$IPAddress
  )
 
  Process {
    ConvertTo-DottedDecimalIP ([Convert]::ToUInt32($IPAddress, 16))
  }
}

Function ConvertTo-BinaryIP {
  <#
    .Synopsis
      Converts a Decimal IP address into a binary format.
    .Description
      ConvertTo-BinaryIP uses System.Convert to switch between decimal and binary format. The output from this function is dotted binary.
    .Parameter IPAddress
      An IP Address to convert.
  #>

  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True)]
    [Net.IPAddress]$IPAddress
  )

  Process {  
    Return [String]::Join('.', $( $IPAddress.GetAddressBytes() | ForEach-Object { [Convert]::ToString($_, 2).PadLeft(8, '0') } ))
  }
}

Function ConvertTo-DecimalIP {
  <#
    .Synopsis
      Converts a Decimal IP address into a 32-bit unsigned integer.
    .Description
      ConvertTo-DecimalIP takes a decimal IP, uses a shift-like operation on each octet and returns a single UInt32 value.
    .Parameter IPAddress
      An IP Address to convert.
  #>
  
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True)]
    [Net.IPAddress]$IPAddress
  )

  Process {
    $i = 3; $DecimalIP = 0;
    $IPAddress.GetAddressBytes() | ForEach-Object { $DecimalIP += $_ * [Math]::Pow(256, $i); $i-- }

    Return [UInt32]$DecimalIP
  }
}

Function ConvertTo-DottedDecimalIP {
  <#
    .Synopsis
      Returns a dotted decimal IP address from either an unsigned 32-bit integer or a dotted binary string.
    .Description
      ConvertTo-DottedDecimalIP uses a regular expression match on the input string to convert to an IP address.
    .Parameter IPAddress
      A string representation of an IP address from either UInt32 or dotted binary format.
  #>

  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True)]
    [String]$IPAddress
  )
  
  Process {
    Switch -RegEx ($IPAddress) {
      "([01]{8}\.){3}[01]{8}" {

        Return [String]::Join('.', $( $IPAddress.Split('.') | ForEach-Object { [Convert]::ToInt32($_, 2) } ))
      }
      "\d" {

        $IPAddress = [UInt32]$IPAddress
        $DottedIP = $( For ($i = 3; $i -gt -1; $i--) {
          $Remainder = $IPAddress % [Math]::Pow(256, $i)
          ($IPAddress - $Remainder) / [Math]::Pow(256, $i)
          $IPAddress = $Remainder
         } )
       
        Return [String]::Join('.', $DottedIP)
      }
      default {
        Write-Error "Cannot convert this format"
      }
    }
  }
}

Function ConvertTo-MaskLength {
  <#
    .Synopsis
      Returns the length of a subnet mask.
    .Description
      ConvertTo-MaskLength accepts any IPv4 address as input, however the output value only makes sense when using a subnet mask.
    .Parameter SubnetMask
      A subnet mask to convert into length
  #>

  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True)]
    [Alias("Mask")]
    [Net.IPAddress]$SubnetMask
  )

  Process {
    $Bits = "$( $SubnetMask.GetAddressBytes() | ForEach-Object { [Convert]::ToString($_, 2) } )" -Replace "[\s0]"

    Return $Bits.Length
  }
}

Function ConvertTo-Mask {
  <#
    .Synopsis
      Returns a dotted decimal subnet mask from a mask length.
    .Description
      ConvertTo-Mask returns a subnet mask in dotted decimal format from an integer value ranging between 0 and 32. ConvertTo-Mask first creates a binary string from the length, converts that to an unsigned 32-bit integer then calls ConvertTo-DottedDecimalIP to complete the operation.
    .Parameter MaskLength
      The number of bits which must be masked.
  #>
  
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True)]
    [Alias("Length")]
    [ValidateRange(0, 32)]
    $MaskLength
  )
  
  Process {
    Return ConvertTo-DottedDecimalIP ([Convert]::ToUInt32($(("1" * $MaskLength).PadRight(32, "0")), 2))
  }
}

Function Get-NetworkAddress {
  <#
    .Synopsis
      Takes an IP address and subnet mask then calculates the network address for the range.
    .Description
      Get-NetworkAddress returns the network address for a subnet by performing a bitwise AND operation against the decimal forms of the IP address and subnet mask. Get-NetworkAddress expects both the IP address and subnet mask in dotted decimal format.
    .Parameter IPAddress
      Any IP address within the network range.
    .Parameter SubnetMask
      The subnet mask for the network.
  #>
  
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True)]
    [Net.IPAddress]$IPAddress,
    
    [Parameter(Mandatory = $True, Position = 1, ValueFromPipelineByPropertyName = $True)]
    [Alias("Mask")]
    [Net.IPAddress]$SubnetMask
  )

  Process {
    Return ConvertTo-DottedDecimalIP ((ConvertTo-DecimalIP $IPAddress) -BAnd (ConvertTo-DecimalIP $SubnetMask))
  }
}

Function Get-BroadcastAddress {
  <#
    .Synopsis
      Takes an IP address and subnet mask then calculates the broadcast address for the range.
    .Description
      Get-BroadcastAddress returns the broadcast address for a subnet by performing a bitwise AND operation against the decimal forms of the IP address and inverted subnet mask. Get-BroadcastAddress expects both the IP address and subnet mask in dotted decimal format.
    .Parameter IPAddress
      Any IP address within the network range.
    .Parameter SubnetMask
      The subnet mask for the network.
  #>
  
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True)]
    [Net.IPAddress]$IPAddress, 
    
    [Parameter(Mandatory = $True, Position = 1, ValueFromPipelineByPropertyName = $True)]
    [Alias("Mask")]
    [Net.IPAddress]$SubnetMask
  )

  Process {
    Return ConvertTo-DottedDecimalIP $((ConvertTo-DecimalIP $IPAddress) -BOr ((-BNot (ConvertTo-DecimalIP $SubnetMask)) -BAnd [UInt32]::MaxValue))
  }
}

Function Get-NetworkSummary {
  <#
    .Synopsis
      Generates a summary of a network range
    .Description
      Get-NetworkSummary uses most of the IP conversion CmdLets to provide a summary of a network
      range from any IP address in the range and a subnet mask.
    .Parameter IPAddress
      Any IP address within the network range.
    .Parameter Network
      A network description in the format 1.2.3.4/24
    .Parameter SubnetMask
      The subnet mask for the network.
  #>
 
  [CmdLetBinding(DefaultParameterSetName = "IPAndMask")]
  Param(
    [Parameter(Mandatory = $True, Position = 0, ParameterSetName = "IPAndMask", ValueFromPipeline = $True)]
    [Net.IPAddress]$IPAddress,
 
    [Parameter(Mandatory = $True, Position = 1, ParameterSetName = "IPAndMask")]
    [Alias("Mask")]
    [Net.IPAddress]$SubnetMask,
 
    [Parameter(Mandatory = $True, ParameterSetName = "CIDRNotation", ValueFromPipeline = $True)]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}[\\/]\d{1,2}$')]
    [String]$Network
  )
 
  Process {
    If ($PsCmdLet.ParameterSetName -eq 'CIDRNotation') {
      $Temp = $Network.Split("\/")
      $IPAddress = $Temp[0]
      $SubnetMask = ConvertTo-Mask $Temp[1]
    }
 
    $DecimalIP = ConvertTo-DecimalIP $IPAddress
    $DecimalMask = ConvertTo-DecimalIP $SubnetMask
    $DecimalNetwork =  $DecimalIP -BAnd $DecimalMask
    $DecimalBroadcast = $DecimalIP -BOr ((-BNot $DecimalMask) -BAnd [UInt32]::MaxValue)
 
    $NetworkSummary = New-Object PSObject -Property @{
      "NetworkAddress"   = (ConvertTo-DottedDecimalIP $DecimalNetwork);
      "NetworkDecimal"   = $DecimalNetwork
      "BroadcastAddress" = (ConvertTo-DottedDecimalIP $DecimalBroadcast);
      "BroadcastDecimal" = $DecimalBroadcast
      "Mask"             = $SubnetMask;
      "MaskLength"       = (ConvertTo-MaskLength $SubnetMask);
      "MaskHexadecimal"  = (ConvertTo-HexIP $SubnetMask);
      "HostRange"        = "";
      "NumberOfHosts"    = ($DecimalBroadcast - $DecimalNetwork - 1);
      "Class"            = "";
      "IsPrivate"        = $False}
 
    If ($NetworkSummary.MaskLength -lt 31) {
      $NetworkSummary.HostRange = [String]::Format("{0} - {1}",
        (ConvertTo-DottedDecimalIP ($DecimalNetwork + 1)),
        (ConvertTo-DottedDecimalIP ($DecimalBroadcast - 1)))
    }
 
    Switch -RegEx ($(ConvertTo-BinaryIP $IPAddress)) {
      "^1111"              { $NetworkSummary.Class = "E" }
      "^1110"              { $NetworkSummary.Class = "D" }
      "^11000000.10101000" { $NetworkSummary.Class = "C"; $NetworkSummary.IsPrivate = $True }
      "^110"               { $NetworkSummary.Class = "C" }
      "^10101100.0001"     { $NetworkSummary.Class = "B"; $NetworkSummary.IsPrivate = $True }
      "^10"                { $NetworkSummary.Class = "B" }
      "^00001010"          { $NetworkSummary.Class = "A"; $NetworkSummary.IsPrivate = $True }
      "^0"                 { $NetworkSummary.Class = "A" }
    }   
 
    Return $NetworkSummary
  }
}

Function Get-NetworkRange {
  <#
    .Synopsis
      Generates IP addresses within the specified network.
    .Description
      Get-NetworkRange finds the network and broadcast address as decimal values then starts a
      counter between the two, returning Net.IPAddress for each.
    .Parameter IPAddress
      Any IP address within the network range.
    .Parameter Network
      A network description in the format 1.2.3.4/24
    .Parameter SubnetMask
      The subnet mask for the network.
  #>
 
  [CmdLetBinding(DefaultParameterSetName = "IPAndMask")]
  Param(
    [Parameter(Mandatory = $True, Position = 0, ParameterSetName = "IPAndMask", ValueFromPipeline = $True)]
    [Net.IPAddress]$IPAddress, 
 
    [Parameter(Mandatory = $True, Position = 1, ParameterSetName = "IPAndMask")]
    [Alias("Mask")]
    [Net.IPAddress]$SubnetMask,
 
    [Parameter(Mandatory = $True, ParameterSetName = "CIDRNotation", ValueFromPipeline = $True)]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}[\\/]\d{1,2}$')]
    [String]$Network
  )
 
  Process {
    If ($PsCmdLet.ParameterSetName -eq 'CIDRNotation') {
      $Temp = $Network.Split("\/")
      $IPAddress = $Temp[0]
      $SubnetMask = ConvertTo-Mask $Temp[1]
    }
 
    $DecimalIP = ConvertTo-DecimalIP $IPAddress
    $DecimalMask = ConvertTo-DecimalIP $SubnetMask
 
    $DecimalNetwork = $DecimalIP -BAnd $DecimalMask
    $DecimalBroadcast = $DecimalIP -BOr ((-BNot $DecimalMask) -BAnd [UInt32]::MaxValue)
 
    For ($i = $($DecimalNetwork + 1); $i -lt $DecimalBroadcast; $i++) {
      ConvertTo-DottedDecimalIP $i
    }
  }
}



###############################################################################################################################################################
#                                                                       Socket Handling                                                                       #
###############################################################################################################################################################

Function New-Socket
{
  <#
    .Synopsis
      Creates a socket.
    .Description
      New-Socket creates a socket with System.Net.Sockets.Socket.
    .Parameter EnableBroadcast
      Whether or not the socket will send and receive using the a broadcast address.
    .Parameter IPAddress
      The local IP address used in the end-point for the socket when the socket is bound. [IPAddress]::Any is used by default.
    .Parameter NoTimeout
      If specified the timeout values will be ignored. Send and Receive operations will not timeout.
    .Parameter Port
      The local port if binding is used.
    .Parameter Protocol
      The protocol used by the socket, either TCP or UDP.
    .Parameter ReceiveTimeout
      How long to wait before timing out a receive operation in seconds
    .Parameter SendTimeout
      How long to wait before timing out a send operation in seconds
  #>

  [CmdLetBinding(DefaultParameterSetName = "Socket")]
  Param(
    [Parameter(Mandatory = $True, Position = 0, ParameterSetName = "")]
    [ValidateSet("Tcp", "Udp")]
    [Net.Sockets.ProtocolType]$Protocol,
    
    [Parameter(Position = 1, ParameterSetName = "BoundSocket")]
    [Net.IPAddress]$IPAddress = [Net.IPAddress]::Any,
    
    [Parameter(Position = 2, ParameterSetName = "BoundSocket")]
    [UInt32]$Port,
    
    [Parameter(ParameterSetName = "")]
    [Switch]$EnableBroadcast,

    [Parameter(ParameterSetName = "")]
    [Switch]$NoTimeout,
    
    [Parameter(ParameterSetName = "")]
    [ValidateRange(1, 30)]
    [Int32]$ReceiveTimeOut = 5,
    
    [Parameter(ParameterSetName = "")]
    [ValidateRange(1, 30)]
    [Int32]$SendTimeOut = 5
  )

  Switch ($Protocol)
  {
    $([Net.Sockets.ProtocolType]::Tcp) { $SocketType = [Net.Sockets.SocketType]::Stream }
    $([Net.Sockets.ProtocolType]::Udp) { $SocketType = [Net.Sockets.SocketType]::Dgram } 
  }

  $Socket = New-Object Net.Sockets.Socket(
    "InterNetwork",
    $SocketType,
    $Protocol)
    
  If ($Protocol -eq [Net.Sockets.ProtocolType]::Udp) {
    $Socket.EnableBroadcast = $EnableBroadcast
  }
  $Socket.ExclusiveAddressUse = $False
  If (!$NoTimeout) {
    $Socket.SendTimeOut = $SendTimeOut * 1000
    $Socket.ReceiveTimeOut = $ReceiveTimeOut * 1000
  }

  If ($PsCmdLet.ParameterSetName -eq "BoundSocket") {
    $LocalEndPoint = [Net.EndPoint](New-Object Net.IPEndPoint($IPAddress, $Port))
    $Socket.Bind($LocalEndPoint)
  }

  Return $Socket
}

Function Send-Bytes {
  <#
    .Synopsis
      Sends bytes to the specified IP address and port.
    .Description
      Sends a byte array using the specified socket and end-point.
    .Parameter Data
      A byte array containing the encoded data to send. For TCP streams this CmdLet prefixes the data length.
    .Parameter IPAddress
      The remote IP address to the data to.
    .Parameter Port
      The remote port.
    .Parameter Socket
      The socket to use for this operation
  #>
  
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory = $True, Position = 0)]
    [Net.Sockets.Socket]$Socket,
    
    [Parameter(Mandatory = $True, Position = 1)]
    [Net.IPAddress]$IPAddress,
    
    [Parameter(Mandatory = $True, Position = 2)]
    [UInt32]$Port,
    
    [Parameter(Mandatory = $True)]
    [Byte[]]$Data
  )

  $ServerEndPoint = [Net.EndPoint](New-Object Net.IPEndPoint($IPAddress, $Port))
  
  If ($Socket.ProtocolType -eq [Net.Sockets.ProtocolType]::Tcp) {
    # Prefix the data length for Tcp. Reverse the array to account for endian order.
    # $Length = [BitConverter]::GetBytes([UInt16]$Data.Length); [Array]::Reverse($Length)
    # $Data = $Length + $Data
    
    If (!$Socket.Connected) {
      $Socket.Connect($ServerEndPoint)
    }

    If ($Socket.Connected) {
      [Void]$Socket.Send($Data)
    }
  } Else {
    [Void]$Socket.SendTo($Data, $ServerEndPoint)
  }
}

Function Receive-Bytes {
  <#
    .Synopsis
      Start a receive operation for the specified socket.
    .Description
      Receive-Bytes expects a bound socket as a parameter. This operation will fail if the socket is not bound to a local end-point.
    .Parameter BufferSize
      The size of the receive buffer, by default the buffer is 1024 bytes.
    .Parameter Continuous
      The CmdLet should continue listening until the script is forcefully terminated.
    .Parameter ExpectPackets
      The number of packets Receive-Bytes should expect when using TCP. By default Receive-Bytes keeps trying which may result in a 
      timeout error, closing the underlying connection. If the stream is not continuous, ExpectPackets should be set to 1.
    .Parameter ListenTimeout
      How long the CmdLet should listen for bytes on the connected socket
    .Parameter Socket
      A connected or disconnected socket. If an IP Address and Port is supplied a connection attempt will be made.
  #>
    
  [CmdLetBinding(DefaultParameterSetName = "Timeout")]
  Param(
    [Parameter(Mandatory = $True, Position = 0, ParameterSetName = "")]
    [Net.Sockets.Socket]$Socket,
    
    [Parameter(Position = 1, ParameterSetName = "")]
    [UInt32]$BufferSize = 1024,

    [Parameter(ParameterSetName = "")]
    [Net.IPAddress]$IPAddress,

    [Parameter(ParameterSetName = "")]
    [UInt32]$Port,
    
    [Parameter(ParameterSetName = "Timeout")]
    [TimeSpan]$ListenTimeout = $(New-TimeSpan -Seconds 5),
    
    [Parameter(ParameterSetName = "Continuous")]
    [Switch]$Continuous,
    
    [Parameter(ParameterSetName = "")]
    [UInt32]$ExpectPackets = [UInt32]::MaxValue
  )

  $Buffer = New-Object Byte[] $BufferSize
  # A placeholder for the sender (conencting host)
  $EndPoint = [Net.EndPoint](New-Object Net.IPEndPoint([Net.IPAddress]::Any, 0))

  If ($Socket.ProtocolType -eq [Net.Sockets.ProtocolType]::Udp) {

    $StartTime = Get-Date
    While ($(New-TimeSpan $StartTime $(Get-Date)) -lt $ListenTimeout -Or $Continuous) {

      Try { $BytesReceived = $Socket.ReceiveFrom($Buffer, [Ref]$EndPoint) } Catch { }
      If ($?) { 
        Write-Verbose "Received $BytesReceived from $($EndPoint.Address.IPAddressToString)"
        "" | Select-Object @{n='Data';e={ @(,$Buffer[0..$($BytesReceived - 1)]) }}, @{n='Sender';e={ $EndPoint.Address.IPAddressToString }}
      }
    }
  } Else {
    If (!$Socket.Connected) {
      $ServerEndPoint = [Net.EndPoint](New-Object Net.IPEndPoint($IPAddress, $Port))
      $Socket.Connect($ServerEndPoint)
    }

    $PacketCount = 0  
    Do {
      $PacketCount++
      Try { $BytesReceived = $Socket.Receive($Buffer) } Catch { }
      If ($?) {
        Write-Verbose "Received $BytesReceived from $($Socket.RemoteEndPoint): Connection State: $($Socket.Connected)"
        "" | Select-Object @{n='Data';e={ $Buffer[0..$($BytesReceived - 1)] }}, @{n='Sender';e={ $EndPoint.Address.IPAddressToString }}
      }
    } While ($Socket.Connected -And $BytesReceived -gt 0 -And $PacketCount -lt $ExpectPackets)
  }
}

Function Remove-Socket
{
  <#
    .Synopsis
      Close an open socket
    .Description
      Remove-Socket will close down both send and receive channels then close a socket. Remove-Socket does not have a return value.
    .Parameter Socket
      Any running socket as System.Net.Sockets.Socket.
  #>

  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory = $True, Position = 0)]
    [Net.Sockets.Socket]$Socket
  )

  $Socket.Shutdown("Both")
  $Socket.Close()
}

Function ConvertTo-Byte {
  <#
    .Synopsis
      Returns a byte array representing an ASCII string.
    .Parameter String
      The string value to convert.
  #>

  Param(
    [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
    [String]$String
  )
  
  Process {
    Return [Text.Encoding]::ASCII.GetBytes($String)
  }
}        

Function ConvertTo-String {
  <#
    .Synopsis
      Returns a byte array representing an ASCII string.
    .Parameter Data
      The Byte Array to convert
  #>

  Param(
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
    [Byte[]]$Data
  ) 
  
  Process {
    Return [Text.Encoding]::ASCII.GetString($Data)
  }
}

Function Test-TcpPort {
  <#
    .Synopsis
      Test a TCP Port.
    .Description
      Test-TcpPort establishes a TCP connection to the sepecified port then immediately closes the connection, returning whether or not the
      connection succeeded.
    .Parameter IPAddress
      An IP address for the server system
    .Parameter Port
      The port number to connect to
    .Example
      Test-TcpPort "10.75.1.17" 3389
  #>

  Param(
    [Parameter(Mandatory = $True)]
    [Net.IPAddress]$IPAddress,
    [Parameter(Mandatory = $True)]
    [UInt32]$Port
  )

  $TcpClient = New-Object Net.Sockets.TcpClient
  Try { $TcpClient.Connect($IPAddress, $Port) } Catch { }
  If ($?) {
    Return $True
    $TcpClient.Close()
  }
  Return $False
}

###############################################################################################################################################################
#                                                                            DHCP                                                                             #
###############################################################################################################################################################

<#
  DHCP Packet Format (RFC 2131 - http://www.ietf.org/rfc/rfc2131.txt):

  0                   1                   2                   3
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |     op (1)    |   htype (1)   |   hlen (1)    |   hops (1)    |
  +---------------+---------------+---------------+---------------+
  |                            xid (4)                            |
  +-------------------------------+-------------------------------+
  |           secs (2)            |           flags (2)           |
  +-------------------------------+-------------------------------+
  |                          ciaddr  (4)                          |
  +---------------------------------------------------------------+
  |                          yiaddr  (4)                          |
  +---------------------------------------------------------------+
  |                          siaddr  (4)                          |
  +---------------------------------------------------------------+
  |                          giaddr  (4)                          |
  +---------------------------------------------------------------+
  |                                                               |
  |                          chaddr  (16)                         |
  |                                                               |
  |                                                               |
  +---------------------------------------------------------------+
  |                                                               |
  |                          sname   (64)                         |
  +---------------------------------------------------------------+
  |                                                               |
  |                          file    (128)                        |
  +---------------------------------------------------------------+
  |                                                               |
  |                          options (variable)                   |
  +---------------------------------------------------------------+

   FIELD      OCTETS       DESCRIPTION
   -----      ------       -----------

   op            1  Message op code / message type.
                    1 = BOOTREQUEST, 2 = BOOTREPLY
   htype         1  Hardware address type, see ARP section in "Assigned
                    Numbers" RFC; e.g., '1' = 10mb ethernet.
   hlen          1  Hardware address length (e.g.  '6' for 10mb
                    ethernet).
   hops          1  Client sets to zero, optionally used by relay agents
                    when booting via a relay agent.
   xid           4  Transaction ID, a random number chosen by the
                    client, used by the client and server to associate
                    messages and responses between a client and a
                    server.
   secs          2  Filled in by client, seconds elapsed since client
                    began address acquisition or renewal process.
   flags         2  Flags (see figure 2).
   ciaddr        4  Client IP address; only filled in if client is in
                    BOUND, RENEW or REBINDING state and can respond
                    to ARP requests.
   yiaddr        4  'your' (client) IP address.
   siaddr        4  IP address of next server to use in bootstrap;
                    returned in DHCPOFFER, DHCPACK by server.
   giaddr        4  Relay agent IP address, used in booting via a
                    relay agent.
   chaddr       16  Client hardware address.
   sname        64  Optional server host name, null terminated string.
   file        128  Boot file name, null terminated string; "generic"
                    name or null in DHCPDISCOVER, fully qualified
                    directory-path name in DHCPOFFER.
   options     var  Optional parameters field.  See the options
                    documents for a list of defined options.
#>

Function New-DhcpDiscoverPacket {
  <#
    .Synopsis
      Creates a DHCP discover packet
    .Description
      New-DhcpDiscoverPacket creates a byte array representing a DHCP discover request containing the specified MAC address.
    .Parameter MACAddressString
      A MAC address which will be embedded in the request. Note that sending discovery will not grant a lease to the MAC address.
  #>
  
  [CmdLetBinding()]
  Param(
    [Parameter(Position = 0)]
    [String]$MacAddressString = "AA:BB:CC:DD:EE:FF"
  )

  # Generate a Transaction ID for this request

  $XID = New-Object Byte[] 4
  $Random = New-Object Random
  $Random.NextBytes($XID)

  # Convert the MAC Address String into a Byte Array

  # Drop any characters which might be used to delimit the string
  $MacAddressString = $MacAddressString -Replace "-|:|\."
  $MacAddress = [BitConverter]::GetBytes(([UInt64]::Parse($MacAddressString, [Globalization.NumberStyles]::HexNumber)))
  # Reverse the MAC Address array
  [Array]::Reverse($MacAddress)

  # Create the Byte Array
  $DhcpDiscover = New-Object Byte[] 243

  # Copy the Transaction ID Bytes into the array
  [Array]::Copy($XID, 0, $DhcpDiscover, 4, 4)

  # Copy the MacAddress Bytes into the array (drop the first 2 bytes,
  # too many bytes returned from UInt64)
  [Array]::Copy($MACAddress, 2, $DhcpDiscover, 28, 6)

  # Set the OP Code to BOOTREQUEST
  $DhcpDiscover[0] = 1
  # Set the Hardware Address Type to Ethernet
  $DhcpDiscover[1] = 1
  # Set the Hardware Address Length (number of bytes)
  $DhcpDiscover[2] = 6
  # Set the Broadcast Flag
  $DhcpDiscover[10] = 128
  # Set the Magic Cookie values
  $DhcpDiscover[236] = 99
  $DhcpDiscover[237] = 130
  $DhcpDiscover[238] = 83
  $DhcpDiscover[239] = 99
  # Set the DHCPDiscover Message Type Option
  $DhcpDiscover[240] = 53
  $DhcpDiscover[241] = 1
  $DhcpDiscover[242] = 1

  Return $DhcpDiscover
}

Function Read-DhcpOption {
  <#
    .Synopsis
      Read-DhcpOption returns a DHCP Option read from a DHCP packet.
    .Description
      Read-DhcpOption accepts the extended binary reader class as input, returning an individual option description.
    .Parameter Reader
      An object containing an instance of the Extended.BinaryReader class.
  #>
  
  [CmdLetBinding()]
  Param(
    [Parameter( Mandatory = $True )]
    [Extended.BinaryReader]$Reader
  )

  $Option = New-Object Object
  $Option | Add-Member NoteProperty OptionCode $Reader.ReadByte()
  $Option | Add-Member NoteProperty OptionName ""
  $Option | Add-Member NoteProperty Length 0
  $Option | Add-Member NoteProperty OptionValue ""

  If ($Option.OptionCode -ne 0 -And $Option.OptionCode -ne 255) {
    $Option.Length = $Reader.ReadByte()
  }

  Switch ($Option.OptionCode) {
    0 { $Option.OptionName = "PadOption" }
    1 {
      $Option.OptionName = "SubnetMask"
      $Option.OptionValue = $Reader.ReadIPAddress() }
    3 {
      $Option.OptionName = "Router"
      $Option.OptionValue = $Reader.ReadIPAddress() }
    6 {
      $Option.OptionName = "DomainNameServer"
      $Option.OptionValue = @()
      For ($i = 0; $i -lt ($Option.Length / 4); $i++) {
        $Option.OptionValue += $Reader.ReadIPAddress()
      } }
    15 {
      $Option.OptionName = "DomainName"
      $Option.OptionValue = New-Object String(@(,$Reader.ReadChars($Option.Length))) }
    51 {
      $Option.OptionName = "IPAddressLeaseTime"
      $Option.OptionValue = New-TimeSpan -Seconds $($Reader.ReadUInt32($True)) }
    53 {
      $Option.OptionName = "DhcpMessageType"
      $Option.OptionValue = [Dhcp.RequestType]$Reader.ReadByte() }
    54 {
      $Option.OptionName = "DhcpServerIdentifier"
      $Option.OptionValue = $Reader.ReadIPAddress(); }
    58 {
      $Option.OptionName = "RenewalTime"
      $Option.OptionValue = New-TimeSpan -Seconds $($Reader.ReadUInt32($True)) }
    59 {
      $Option.OptionName = "RebindingTime"
      $Option.OptionValue = New-TimeSpan -Seconds $($Reader.ReadUInt32($True)) }
    255 { $Option.OptionName = "EndOption" }
    default {
      # For all options which are not decoded here
      $Option.OptionName = "NoOptionDecode"
      $Buffer = New-Object Byte[] $Option.Length
      [Void]$Reader.Read($Buffer, 0, $Option.Length)
      $Option.OptionValue = $Buffer
    }
  }

  # Override the ToString method
  $Option | Add-Member ScriptMethod ToString { Return "$($this.OptionName) ($($this.OptionValue))" } -Force
  
  Return $Option
}

Function Read-DhcpPacket {
  <#
    .Synopsis
      Converts a byte array response from a DHCP request to an object.
    .Description
      Accepts a byte array on the pipeline and outputs an object representing the DHCP packet.
    .Parameter Data
      A byte array representing the DHCP packet.
  #>
  
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True, Position = 0)]
    [Byte[]]$Data
  )
  
  Process {
  
    $Reader = New-Object Extended.BinaryReader(New-Object IO.MemoryStream(@(,$Data)))
    $DhcpResponse = New-Object Object

    # Get and translate the Op code
    $DhcpResponse | Add-Member NoteProperty Op $Reader.ReadByte()
    If ($DhcpResponse.Op -eq 1)  {
      $DhcpResponse.Op = "BootRequest"
    } Else {
      $DhcpResponse.Op = "BootResponse"
    }

    $DhcpResponse | Add-Member NoteProperty HType -Value $Reader.ReadByte()
    If ($DhcpResponse.HType -eq 1) { $DhcpResponse.HType = "Ethernet" }

    $DhcpResponse | Add-Member NoteProperty HLen $Reader.ReadByte()
    $DhcpResponse | Add-Member NoteProperty Hops $Reader.ReadByte()
    $DhcpResponse | Add-Member NoteProperty XID $Reader.ReadUInt32()
    $DhcpResponse | Add-Member NoteProperty Secs $Reader.ReadUInt16()
    $DhcpResponse | Add-Member NoteProperty Flags $Reader.ReadUInt16()
    # Broadcast is the only flag that can be present, the other bits are reserved
    if ($DhcpResponse.Flags -BAnd 128) { $DhcpResponse.Flags = @("Broadcast") }

    $DhcpResponse | Add-Member NoteProperty CIAddr $($Reader.ReadIPAddress())
    $DhcpResponse | Add-Member NoteProperty YIAddr $($Reader.ReadIPAddress())
    $DhcpResponse | Add-Member NoteProperty SIAddr $($Reader.ReadIPAddress())
    $DhcpResponse | Add-Member NoteProperty GIAddr $($Reader.ReadIPAddress())

    $MacAddrBytes = New-Object Byte[] 16
    [Void]$Reader.Read($MacAddrBytes, 0, 16)
    $MacAddress = [String]::Join(":", $($MacAddrBytes[0..5] | ForEach-Object { [String]::Format('{0:X2}', $_) }))
    $DhcpResponse | Add-Member NoteProperty CHAddr $MacAddress

    $DhcpResponse | Add-Member NoteProperty SName $((New-Object String(@(,$Reader.ReadChars(64)))) -Replace [Char]0)
    $DhcpResponse | Add-Member NoteProperty File $((New-Object String(@(,$Reader.ReadChars(128)))) -Replace [Char]0)

    $DhcpResponse | Add-Member NoteProperty MagicCookie $($Reader.ReadIPAddress())

    # Start reading Options

    $DhcpResponse | Add-Member NoteProperty Options @()
    While ($Reader.BaseStream.Position -lt $Reader.BaseStream.Length) {
      $DhcpResponse.Options += $(Read-DhcpOption $Reader)
    }

    Return $DhcpResponse
  }
}

Function Send-DhcpDiscover {
  <#
    .Synopsis
      Creates and sends a DHCP Discover request
    .Description
      Send-DhcpDiscover creates a DHCP packet using the specified MAC address and sends it to the broadcast IP address (255.255.255.255) then waits for a response.
    .Parameter ListenTimeout
      Send-DhcpDiscover will listen for the the specified TimeSpan, by default Send-DhcpDiscover listens for 30 seconds.
    .Parameter MacAddress
      The MAC address encapsulated in the request. The default value is AA:BB:CC:DD:EE:FF.
  #>

  [CmdLetBinding()]
  Param(
    [String]$MacAddress = "AA:BB:CC:DD:EE:FF",
    
    [TimeSpan]$ListenTimeout = $(New-TimeSpan -Seconds 30)
  )
  
  $Data = New-DhcpDiscoverPacket -MacAddressString $MacAddress
  $Socket = New-Socket -Protocol Udp -Port 68 -EnableBroadcast
  Send-Bytes -Socket $Socket -IPAddress $([Net.IPAddress]::Broadcast) -Port 67 -Data $Data
  
  Receive-Bytes -Socket $Socket -ListenTimeout $ListenTimeout | Read-DhcpPacket
  Remove-Socket $Socket
}

###############################################################################################################################################################
#                                                                           SysLog                                                                            #
###############################################################################################################################################################

Function Test-SysLogPRI {
  <#
    .Synopsis
      Reads the PRI value from a SysLog message.
    .Description
      Reads the PRI value from a SysLog message. If the value is incorrectly formatted or out of range
      a value of 13 will be returned as discussed in RFC 3164 section 4.3.3.
    .Parameter MessageString
      The SysLog message to test.
  #>

  Param(
    [Parameter(Mandatory = $True)]
    [String]$MessageString
  )

  If (!$MessageString.StartsWith("<") -Or !($MessageString[2..4] -Contains ">")) {
    Return 13
  }

  $PRI = [Int]($MessageString -Replace "<|>.*")
  # PRI = (Facility * 8) + Severity. Maximum and minimum values from RFC 3164
  If ($PRI -lt 1 -Or $PRI -gt 191) {
    Return 13
  }
  Return $PRI
}

Function Test-SysLogDateTime {
  <#
    .Synopsis
      Reads the date value from a SysLog message.
    .Description
      Reads the data value from a SysLog message and returns True or False depending on whether the date is in the expected format or not.
    .Parameter MessageString
      The SysLog message to test.
  #>

  Param(
    [Parameter(Mandatory = $True)]
    [String]$MessageString
  )

  $IsValid = $False
  If ($MessageString -Match '(?<=\>)\w{3}\s\s?\d{1,2}\s\d{2,4}\s(\d\d:){2}\d\d(?=\s)') {
    $Date = New-Object DateTime
    ForEach ($Format in @("MMM  d yyyy hh:mm:ss", "MMM dd yyyy hh:mm:ss", "MMM  d hh:mm:ss", "MMM dd hh:mm:ss")) {
      [Ref]$Date = New-Object DateTime
      $IsValid = [DateTime]::TryParseExact(
        $Matches[0],
        $Format,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AssumeUniversal,
        $Date)
      If ($IsValid) { Return $True }
    }
  }
  Return $False
}

Function New-SysLogDateTime {
  <#
    .Synopsis
      Returns a formatted date string to insert into a SysLog message.
  #>

  $Date = (Get-Date).ToUniversalTime()
  If ($Date.Day -lt 10)
  {
    Return $Date.ToString("MMM  d yyyy HH:mm:ss")
  }
  Return $Date.ToString("MMM dd yyyy HH:mm:ss")
}

Function Start-Syslog {
  <#
    .Synopsis
      A basic syslog server
    .Description
      Start-Syslog sets up a basic SysLog server. By default messages are logged to the console. Note that this function never terminates.
    .Parameter BufferSize
      The default buffer size for SysLog is 1024 bytes. This is passed to Receive-Bytes as the buffer size.
    .Parameter DropFQDN
      If the hostname value does not parse as an IP address, everything after the first period (.) will be dropped.
    .Parameter HostnameLookup
      Lookup the hostname in DNS.
    .Parameter ListenPort
      The SysLog server should listen on this port. By default Syslog binds to UDP port 514.
    .Parameter LogFolder
      Log messages to the specified folder.
    .Parameter Quiet
      Do not log messages to the console.
    .Parameter Relay
      Relay DHCP messages to the specified host.
    .Parameter RelayPort
      By default, Start-SysLog relays to UDP Port 514.
    .Parameter ValidateMessage
      Check the validity of the SysLog message. This is enabled by default in an attempt to conform with RFC 3164.
  #>
  
  [CmdLetBinding()]
  Param(
    [Net.IPAddress]$Relay,
    
    [UInt32]$RelayPort = 514,
    
    [ValidateScript( { Test-Path $_ } )]
    [String]$LogFolder,
    
    [UInt32]$ListenPort = 514,
    
    [UInt32]$BufferSize = 1024,

    [Switch]$Quiet,

    [Boolean]$ValidateMessage = $True,

    [Boolean]$HostnameLookup = $True,
    
    [Switch]$DropFQDN
  )

  $Socket = New-Socket -Protocol Udp -Port $ListenPort -NoTimeout
  Receive-Bytes -Socket $Socket -BufferSize $BufferSize -Continuous | ForEach-Object {
  
    If ($ValidateMessage -Or $LogFilePath -Or !$Quiet) {
    
      $MessageString = ConvertTo-String $_.Data
      
      If ($HostnameLookup) {
        Try { $HostEntry = [Net.Dns]::GetHostEntry($_.Sender) } Catch { }
        If ($?) {
          $Hostname = $HostEntry.HostName
        }
      }

      If ($DropFQDN -And !([Net.IPAddress]::TryParse($HostName, [Ref]$Null))) {
        $Hostname = $HostName -Replace '\..*'
      }
      
      If ($ValidateMessage) {
      
        $PRI = Test-SysLogPRI $MessageString
        
        If ($PRI -eq 13 -Or !(Test-SysLogDateTime $MessageString)) {
          $MessageString = "<$PRI>$(New-SysLogDateTime) $HostName $MessageString"
        }

        $Message = ConvertTo-Byte $MessageString
        If ($Message.Length -gt 1024) {
          $Message = $Message[0..1023]
        }
      }
      
      If ($LogFolder) {
        $MessageString | Out-File "$LogFolder\$Hostname-$((Get-Date).ToString('yyyy.MM.dd'))" -Append
      }
      
      $MessageString
    }

    If ($Relay) {
      Send-Bytes -Socket $Socket -IPAddress $Relay -Port $RelayPort -Data $Message
    }
  }
}

###############################################################################################################################################################
#                                                                           SMTP                                                                              #
###############################################################################################################################################################

Function Test-Smtp {
  <#
    .Synopsis
      A function to return and decode an SMTP banner from a remote SMTP server.
    .Description
      Get-SmtpBanner creates a TCP connection, such as an SMTP server, and converts the return value to a string.
    .Parameter From
      A sender address.
    .Parameter IPAddress
      The server to connect to.
    .Parameter Port
      The TCP Port to use. By default, Port 25 is used.
    .Parameter To
      The recipient of the test e-mail.
  #>

  Param(
    [Parameter(Mandatory = $True)]
    [Net.IPAddress]$IPAddress,
    
    [UInt32]$Port = 25,

    [Parameter(Mandatory = $True)]
    [String]$To,
    
    [Parameter(Mandatory = $True)]
    [String]$From
  )

  $CommandList = "helo there", "mail from: $From", "rcpt to: $To", "data", "Subject: Test message from Test-Smtp: $(Get-Date)`r`n."

  $Socket = New-Socket -Protocol Tcp

  # Get the banner
  "" | Select-Object @{n='Operation';e={ "RECEIVE" }}, @{n='Data';e={
    Receive-Bytes $Socket -IPAddress $IPAddress -Port $Port -ExpectPackets 1 -ListenTimeout (New-TimeSpan -Seconds 30) | ConvertTo-String }}

  # Send the remaining commands (terminated with CRLF, `r`n) and get the response
  $CommandList | ForEach-Object {
    $_ | Select-Object @{n='Operation';e={ "SEND" }}, @{n='Data';e={ $_ }}
    Send-Bytes $Socket -IPAddress $IPAddress -Port $Port -Data $(ConvertTo-Byte "$_`r`n")

    "" | Select-Object @{n='Operation';e={ "RECEIVE" }}, @{n='Data';e={
      Receive-Bytes $Socket -IPAddress $IPAddress -Port $Port -ExpectPackets 1 -ListenTimeout (New-TimeSpan -Seconds 30) | ConvertTo-String }}
  }
  Remove-Socket $Socket
}