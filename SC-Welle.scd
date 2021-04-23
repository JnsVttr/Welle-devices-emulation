
////////////////////////////////////////////////////////////
// SC Welle
////////////////////////////////////////////////////////////





////////////////////////////////////////////////////////////
// Object for all
i = ();
// global vars
i.pattern = [1,0,0,0,0,0,0,0];
i.volume = 0.1;
i.envelope = [ [ 0, 0.1, 0.3, 1 ], [ 0, 1, 0.4, 0 ] ] ; // atk, dec, sus, rel
i.eq = [[0.0, 0.3, 0.7, 1.0], [0.5, 0.5, 0.5, 0.5]];
i.stringInput = 0;
// conversions
i.volumeMap = ControlSpec.new(0, 126, \lin);  // CC 0-126


////////////////////////////////////////////////////////////
// START MIDI function
i.startMIDI = {
	MIDIClient.init;
	i.midiOut = MIDIOut.newByName("IAC-Treiber","Bus 1");
	defer {
		i.midiStartButton.states = [["MIDI \n Connected", Color.black, Color.green]];// GUI actions..
		i.updateWindow.value;
	};
	i.midiOut.noteOn(16, 60, 60);
	i.midiOut.control(1, 15, 120);

	// tests
	i.interactionGUI(['setEnvelope', i.convertEnv([0.1, 0.2, 0.4, 0.3])]);
	i.interactionGUI(['setEq', i.convertEq([0.7, 0.2, 0.4, 0.7, 0.6])]);
	defer { i.updateWindow() };
};

////////////////////////////////////////////////////////////
i.sendMIDI = {|f, message|
	message.postln;
	if (i.midiOut != nil, {
		switch(message[0],
		'sendVolume', {
			i.midiOut.control(1, 9, i.volumeMap.map(message[1]))
		},
		'sendPattern', {
			for (0, 7, {|k|
				if (i.pattern[k]==0, {
					i.midiOut.control(1, k+1, 0)
				}, {
					i.midiOut.control(1, k+1, 1)
				})

			});
		}
		)
	})
};



////////////////////////////////////////////////////////////
// converters
i.convertEnv = {|f, envShort|
	// [0,atk,atk+dec,atk+dec+rel,1]      [0,1,sus,sus,0]
	var envArray = Array2D.new(2,4);
	var atk = envShort[0];
	var dec = envShort[1];
	var sus = envShort[2];
	var rel = envShort[3];
	envArray = [ [0, atk, atk+dec, 1], [0, 1, sus, 0]];
};
i.unConvertEnv = {|f, envLong|
	// [ [ 0, 0.1, 0.6, 1 ], [ 0, 1, 0.4, 0 ] ]
	// [0,atk,atk+dec,atk+dec+rel,1]      [0,1,sus,sus,0]
	var envArray = Array.new(4);
	var atk = envLong[0][1];
	var dec = envLong[0][2]-atk;
	var sus = envLong[1][2];
	var rel = 1-dec-atk;
	envArray = [ atk, dec, sus, rel ];
};

i.convertEq = {|f, settings|
	// [high, highFreq, mid, midFreq, low]
	var high = settings[4];
	var highFreq = settings[3];
	var mid = settings[2];
	var midFreq = settings[1];
	var low = settings[0];
	var eqArray = Array2D.new(2,4);
	eqArray = [[0, midFreq, highFreq, 1], [low, mid, mid, high]];
};
i.unConvertEq = {|f, settings|
	// [[0, midFreq, highFreq, 1], [low, mid, mid, high]]
	var high = settings[1][3];
	var highFreq = settings[0][2];
	var mid = (settings[1][1]+settings[1][2])/2;
	var midFreq = settings[0][1];
	var low = settings[1][0];
	var eqArray = Array.fill(4);
	eqArray = [low, midFreq, mid, highFreq, high];
};



////////////////////////////////////////////////////////////
// respon to changed GUI
i.interactionGUI = {|f, message|
	message.postln;
	switch (message[0],
		'setVolume', {
			i.volume = message[1];
			// postf("set volume: %\n", i.volume);
			i.sendMIDI(['sendVolume', i.volume])
		},
		'setPattern', {
			var c = message[1];
			if (i.pattern[c] == 0, {
				i.pattern[c] = 1;
			}, {
				i.pattern[c] = 0
			});
			defer { i.updateWindow() };
			i.sendMIDI(['sendPattern'])
		},
		'setEq', {
			i.eq = message[1];
			i.unConvertEq(i.eq).postln;
		},
		'setEnvelope', {
			i.envelope = message[1];
			i.unConvertEnv(i.envelope).postln;
		},
		'changeInput', {
			if (i.stringInput == 0, {
				i.stringInput = 1;
				i.stringInputButton.states = [["String Input to:\n Envelope", Color.grey, Color.white]];
			}, {
				i.stringInput = 0;
				i.stringInputButton.states = [["String Input to:\n EQ", Color.grey, Color.white]];
			})
		},
		{ postf("default: post message %\n", message); }
	);
};



////////////////////////////////////////////////////////////
// update Window function
i.updateWindow = {
	("update window").postln;
	defer {
		i.volumeKnob.value = i.volume;
		for (0, 7, {|k|
			if (i.pattern[k]==1, {
				// ("pattern active").postln;
				i.buttons[k].states = [["", Color.white, Color.black]];
			}, {
				i.buttons[k].states = ["", Color.grey, Color.white];
			})

		});
		i.envelopeView.value = i.envelope;
		i.eqView.value = i.eq;
	}
};




////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////
// make WINDOW
i.makeWindow = {
	// main window
	i.window = Window.new("Tangible Signals - Welle Test", Rect(100, 600, 1130, 300))
	.front
	.background_(Color.white);


	// layout for device elements
	i.row = HLayoutView(i.window, Rect(10,150,1100,70));
	////////////////////////////////////////////////////////////
	// add volume knob
	i.volumeKnob = Knob(i.row, Rect(60, 10, 80, 50))
	.value_(0.4)
	.action_({|j|
		//postf("action func called: %\n", j.value);
		i.interactionGUI(['setVolume', j.value]);
	});
	////////////////////////////////////////////////////////////
	// make 8 track patterns
	i.buttons = Array.fill(8, nil);
	i.buttonRow = CompositeView(i.row, Rect(0, 0, 370, 80))
	.background_(Color.white);
	for (0, 7, {|k|
		i.buttons[k] = Button(i.buttonRow,Rect(k*45,0,40,70)).states_([["", Color.grey, Color.white]])
		.action_({|j|
			i.interactionGUI(['setPattern', k]);
		});
	});
	////////////////////////////////////////////////////////////
	// make eq
	i.eqView = EnvelopeView(i.row, Rect(400, 0, 230, 80))
	.drawLines_(true)
	.selectionColor_(Color.red)
	.drawRects_(true)
	.resize_(5)
	.step_(0.05)
	.action_({|b|
		i.interactionGUI(['setEq', b.value])
	})
	.thumbSize_(12)
	.value_([[0.0, 0.1, 0.5, 1.0],[0.5, 0.5, 0.5, 0.5]]);
	////////////////////////////////////////////////////////////
	// make envelope
	i.envelopeView = EnvelopeView(i.row, Rect(400, 0, 230, 80))
	.drawLines_(true)
	.selectionColor_(Color.red)
	.drawRects_(true)
	.resize_(5)
	.step_(0.001)
	.action_({|b|
		i.interactionGUI(['setEnvelope', b.value])
	})
	.thumbSize_(12)
	.value_([[0.0, 0.1, 0.5, 1.0],[0.0,1.0,0.8,0.0]]);




	// interaction:
	i.interactionRow = HLayoutView(i.window, Rect(10,10,1100,100)).background_(Color.black);

	// make knob for selecting instruments
	////////////////////////////////////////////////////////////
	// spacer
	c = CompositeView(i.interactionRow, Rect(0, 0, 20, 30));
	// add volume knob
	i.selectInstrumentKnob = Knob(i.interactionRow, Rect(60, 10, 90, 90))
	.value_(0)
	.action_({|j|
		/*~setVolume.value(j.value, i);*/
	});
	// spacer
	c = CompositeView(i.interactionRow, Rect(0, 0, 20, 30));
	// instrument index
	i.instIndex = StaticText.new(i.interactionRow, Rect(0, 0, 80, 60)).stringColor_(Color.white).string_("Inst 1/1");
	////////////////////////////////////////////////////////////
	// add pattern knob
	i.selectPatternKnob = Knob(i.interactionRow, Rect(60, 10, 90, 90))
	.value_(0)
	.action_({|j|
		/*~setVolume.value(j.value, i);*/
	});
	// spacer
	c = CompositeView(i.interactionRow, Rect(0, 0, 20, 30));
	// instrument index
	i.instIndex = StaticText.new(i.interactionRow, Rect(0, 0, 90, 60)).stringColor_(Color.white).string_("Pattern 1/1");


	////////////////////////////////////////////////////////////
	// start interaction button
	i.midiStartButton = Button(i.interactionRow,Rect(0,0,100,10)).states_([["MIDI\n connect to IAC", Color.grey, Color.white]])
	.action_({
		i.startMIDI.value;
	});
	// spacer
	c = CompositeView(i.interactionRow, Rect(0, 0, 40, 30));
	// string input choose
	i.stringInputButton = Button(i.interactionRow,Rect(0,0,100,10)).states_([["String Input to:\n EQ", Color.grey, Color.white]])
	.action_({|b|
		i.interactionGUI(['changeInput'])
	});
};



////////////////////////////////////////////////////////////
// Start process
i.makeWindow.value;
i.updateWindow.value;