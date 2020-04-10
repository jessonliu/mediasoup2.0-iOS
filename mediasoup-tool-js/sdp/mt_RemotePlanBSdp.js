


function send_createAnswerSdp(rtpParametersByKind, localSdpObj, transporParameters)
{
    const transportLocalParameters = transporParameters.transportLocalParameters;
    const transportRemoteParameters = transporParameters.transportRemoteParameters;
    const sdpGlobalFields = transporParameters.sdpGlobalFields;
    
    const remoteIceParameters = transportRemoteParameters.iceParameters;
    const remoteIceCandidates = transportRemoteParameters.iceCandidates;
    const remoteDtlsParameters = transportRemoteParameters.dtlsParameters;
    const sdpObj = {};
    const mids = (localSdpObj.media || [])
    .map((m) => String(m.mid));
    
    // Increase our SDP version.
    sdpGlobalFields.version++;
    
    sdpObj.version = 0;
    sdpObj.origin =
    {
        address        : '0.0.0.0',
        ipVer          : 4,
        netType        : 'IN',
        sessionId      : sdpGlobalFields.id,
        sessionVersion : sdpGlobalFields.version,
        username       : 'mediasoup-client'
    };
    sdpObj.name = '-';
    sdpObj.timing = { start: 0, stop: 0 };
    sdpObj.icelite = remoteIceParameters.iceLite ? 'ice-lite' : null;
    sdpObj.msidSemantic =
    {
        semantic : 'WMS',
        token    : '*'
    };
    sdpObj.groups =
    [
     {
     type : 'BUNDLE',
     mids : mids.join(' ')
     }
     ];
    sdpObj.media = [];
    
    // NOTE: We take the latest fingerprint.
    const numFingerprints = remoteDtlsParameters.fingerprints.length;
    
    sdpObj.fingerprint =
    {
        type : remoteDtlsParameters.fingerprints[numFingerprints - 1].algorithm,
        hash : remoteDtlsParameters.fingerprints[numFingerprints - 1].value
    };
    
    for (const localMediaObj of localSdpObj.media || [])
    {
        const kind = localMediaObj.type;
        const codecs = rtpParametersByKind[kind].codecs;
        const headerExtensions = rtpParametersByKind[kind].headerExtensions;
        const remoteMediaObj = {};
        
        remoteMediaObj.type = localMediaObj.type;
        remoteMediaObj.port = 7;
        remoteMediaObj.protocol = 'RTP/SAVPF';
        remoteMediaObj.connection = { ip: '127.0.0.1', version: 4 };
        remoteMediaObj.mid = localMediaObj.mid;
        
        remoteMediaObj.iceUfrag = remoteIceParameters.usernameFragment;
        remoteMediaObj.icePwd = remoteIceParameters.password;
        remoteMediaObj.candidates = [];
        
        for (const candidate of remoteIceCandidates)
        {
            const candidateObj = {};
            
            // mediasoup does not support non rtcp-mux so candidates component is
            // always RTP (1).
            candidateObj.component = 1;
            candidateObj.foundation = candidate.foundation;
            candidateObj.ip = candidate.ip;
            candidateObj.port = candidate.port;
            candidateObj.priority = candidate.priority;
            candidateObj.transport = candidate.protocol;
            candidateObj.type = candidate.type;
            if (candidate.tcpType)
                candidateObj.tcptype = candidate.tcpType;
            
            remoteMediaObj.candidates.push(candidateObj);
        }
        
        remoteMediaObj.endOfCandidates = 'end-of-candidates';
        
        // Announce support for ICE renomination.
        // https://tools.ietf.org/html/draft-thatcher-ice-renomination
        remoteMediaObj.iceOptions = 'renomination';
        
        switch (remoteDtlsParameters.role)
        {
            case 'client':
                remoteMediaObj.setup = 'active';
                break;
            case 'server':
                remoteMediaObj.setup = 'passive';
                break;
        }
        
        switch (localMediaObj.direction)
        {
            case 'sendrecv':
            case 'sendonly':
                remoteMediaObj.direction = 'recvonly';
                break;
            case 'recvonly':
            case 'inactive':
                remoteMediaObj.direction = 'inactive';
                break;
        }
        
        // If video, be ready for simulcast.
        if (kind === 'video')
            remoteMediaObj.xGoogleFlag = 'conference';
        
        remoteMediaObj.rtp = [];
        remoteMediaObj.rtcpFb = [];
        remoteMediaObj.fmtp = [];
        
        for (const codec of codecs)
        {
            const rtp =
            {
                payload : codec.payloadType,
                codec   : codec.name,
                rate    : codec.clockRate
            };
            
            if (codec.channels > 1)
                rtp.encoding = codec.channels;
            
            remoteMediaObj.rtp.push(rtp);
            
            if (codec.parameters)
            {
                const paramFmtp =
                {
                    payload : codec.payloadType,
                    config  : ''
                };
                
                for (const key of Object.keys(codec.parameters))
                {
                    if (paramFmtp.config)
                        paramFmtp.config += ';';
                    
                    paramFmtp.config += `${key}=${codec.parameters[key]}`;
                }
                
                if (paramFmtp.config)
                    remoteMediaObj.fmtp.push(paramFmtp);
            }
            
            if (codec.rtcpFeedback)
            {
                for (const fb of codec.rtcpFeedback)
                {
                    remoteMediaObj.rtcpFb.push(
                                               {
                                               payload : codec.payloadType,
                                               type    : fb.type,
                                               subtype : fb.parameter || ''
                                               });
                }
            }
        }
        
        remoteMediaObj.payloads = codecs
        .map((codec) => codec.payloadType)
        .join(' ');
        
        remoteMediaObj.ext = [];
        
        for (const ext of headerExtensions)
        {
            // Don't add a header extension if not present in the offer.
            const matchedLocalExt = (localMediaObj.ext || [])
            .find((localExt) => localExt.uri === ext.uri);
            
            if (!matchedLocalExt)
                continue;
            
            remoteMediaObj.ext.push(
                                    {
                                    uri   : ext.uri,
                                    value : ext.id
                                    });
        }
        
        remoteMediaObj.rtcpMux = 'rtcp-mux';
        remoteMediaObj.rtcpRsize = 'rtcp-rsize';
        
        // Push it.
        sdpObj.media.push(remoteMediaObj);
    }
    return {sdpObj:sdpObj, sdpGlobalFields:sdpGlobalFields};
}


function recv_createOfferSdp(rtpParametersByKind, consumerInfos, transporParameters)
	{

        const transportLocalParameters = transporParameters.transportLocalParameters;
        const transportRemoteParameters = transporParameters.transportRemoteParameters;
        const sdpGlobalFields = transporParameters.sdpGlobalFields;
        const kinds = transporParameters.kinds;

		const remoteIceParameters = transportRemoteParameters.iceParameters;
		const remoteIceCandidates = transportRemoteParameters.iceCandidates;
		const remoteDtlsParameters = transportRemoteParameters.dtlsParameters;
		const sdpObj = {};
		const mids = kinds;

		// Increase our SDP version.
		sdpGlobalFields.version++;

		sdpObj.version = 0;
		sdpObj.origin =
		{
			address        : '0.0.0.0',
			ipVer          : 4,
			netType        : 'IN',
			sessionId      : sdpGlobalFields.id,
			sessionVersion : sdpGlobalFields.version,
			username       : 'mediasoup-client'
		};
		sdpObj.name = '-';
		sdpObj.timing = { start: 0, stop: 0 };
		sdpObj.icelite = remoteIceParameters.iceLite ? 'ice-lite' : null;
		sdpObj.msidSemantic =
		{
			semantic : 'WMS',
			token    : '*'
		};
		sdpObj.groups =
		[
			{
				type : 'BUNDLE',
				mids : mids.join(' ')
			}
		];
		sdpObj.media = [];

		// NOTE: We take the latest fingerprint.
		const numFingerprints = remoteDtlsParameters.fingerprints.length;

		sdpObj.fingerprint =
		{
			type : remoteDtlsParameters.fingerprints[numFingerprints - 1].algorithm,
			hash : remoteDtlsParameters.fingerprints[numFingerprints - 1].value
		};

		for (const kind of kinds)
		{
			const codecs = rtpParametersByKind[kind].codecs;
			const headerExtensions = rtpParametersByKind[kind].headerExtensions;
			const remoteMediaObj = {};

			remoteMediaObj.type = kind;
			remoteMediaObj.port = 7;
			remoteMediaObj.protocol = 'RTP/SAVPF';
			remoteMediaObj.connection = { ip: '127.0.0.1', version: 4 };
			remoteMediaObj.mid = kind;

			remoteMediaObj.iceUfrag = remoteIceParameters.usernameFragment;
			remoteMediaObj.icePwd = remoteIceParameters.password;
			remoteMediaObj.candidates = [];

			for (const candidate of remoteIceCandidates)
			{
				const candidateObj = {};

				// mediasoup does not support non rtcp-mux so candidates component is
				// always RTP (1).
				candidateObj.component = 1;
				candidateObj.foundation = candidate.foundation;
				candidateObj.ip = candidate.ip;
				candidateObj.port = candidate.port;
				candidateObj.priority = candidate.priority;
				candidateObj.transport = candidate.protocol;
				candidateObj.type = candidate.type;
				if (candidate.tcpType)
					candidateObj.tcptype = candidate.tcpType;

				remoteMediaObj.candidates.push(candidateObj);
			}

			remoteMediaObj.endOfCandidates = 'end-of-candidates';

			// Announce support for ICE renomination.
			// https://tools.ietf.org/html/draft-thatcher-ice-renomination
			remoteMediaObj.iceOptions = 'renomination';

			remoteMediaObj.setup = 'actpass';

			if (consumerInfos.some((info) => info.kind === kind))
				remoteMediaObj.direction = 'sendonly';
			else
				remoteMediaObj.direction = 'inactive';

			remoteMediaObj.rtp = [];
			remoteMediaObj.rtcpFb = [];
			remoteMediaObj.fmtp = [];

			for (const codec of codecs)
			{
				const rtp =
				{
					payload : codec.payloadType,
					codec   : codec.name,
					rate    : codec.clockRate
				};

				if (codec.channels > 1)
					rtp.encoding = codec.channels;

				remoteMediaObj.rtp.push(rtp);

				if (codec.parameters)
				{
					const paramFmtp =
					{
						payload : codec.payloadType,
						config  : ''
					};

					for (const key of Object.keys(codec.parameters))
					{
						if (paramFmtp.config)
							paramFmtp.config += ';';

						paramFmtp.config += `${key}=${codec.parameters[key]}`;
					}

					if (paramFmtp.config)
						remoteMediaObj.fmtp.push(paramFmtp);
				}

				if (codec.rtcpFeedback)
				{
					for (const fb of codec.rtcpFeedback)
					{
						remoteMediaObj.rtcpFb.push(
							{
								payload : codec.payloadType,
								type    : fb.type,
								subtype : fb.parameter || ''
							});
					}
				}
			}

			remoteMediaObj.payloads = codecs
				.map((codec) => codec.payloadType)
				.join(' ');

			remoteMediaObj.ext = [];

			for (const ext of headerExtensions)
			{
				// Ignore MID RTP extension for receiving media.
				if (ext.uri === 'urn:ietf:params:rtp-hdrext:sdes:mid')
					continue;

				remoteMediaObj.ext.push(
					{
						uri   : ext.uri,
						value : ext.id
					});
			}

			remoteMediaObj.rtcpMux = 'rtcp-mux';
			remoteMediaObj.rtcpRsize = 'rtcp-rsize';

			remoteMediaObj.ssrcs = [];
			remoteMediaObj.ssrcGroups = [];

			for (const info of consumerInfos)
			{
				if (info.kind !== kind)
					continue;

				remoteMediaObj.ssrcs.push(
					{
						id        : info.ssrc,
						attribute : 'msid',
						value     : `${info.streamId} ${info.trackId}`
					});

				remoteMediaObj.ssrcs.push(
					{
						id        : info.ssrc,
						attribute : 'mslabel',
						value     : info.streamId
					});

				remoteMediaObj.ssrcs.push(
					{
						id        : info.ssrc,
						attribute : 'label',
						value     : info.trackId
					});

				remoteMediaObj.ssrcs.push(
					{
						id        : info.ssrc,
						attribute : 'cname',
						value     : info.cname
					});

				if (info.rtxSsrc)
				{
					remoteMediaObj.ssrcs.push(
						{
							id        : info.rtxSsrc,
							attribute : 'msid',
							value     : `${info.streamId} ${info.trackId}`
						});

					remoteMediaObj.ssrcs.push(
						{
							id        : info.rtxSsrc,
							attribute : 'mslabel',
							value     : info.streamId
						});

					remoteMediaObj.ssrcs.push(
						{
							id        : info.rtxSsrc,
							attribute : 'label',
							value     : info.trackId
						});

					remoteMediaObj.ssrcs.push(
						{
							id        : info.rtxSsrc,
							attribute : 'cname',
							value     : info.cname
						});

					// Associate original and retransmission SSRC.
					remoteMediaObj.ssrcGroups.push(
						{
							semantics : 'FID',
							ssrcs     : `${info.ssrc} ${info.rtxSsrc}`
						});
				}
			}

			// Push it.
			sdpObj.media.push(remoteMediaObj);
		}
        return {sdpObj:sdpObj, sdpGlobalFields:sdpGlobalFields};
    }

