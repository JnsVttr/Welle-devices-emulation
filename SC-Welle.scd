
////////////////////////////////////////////////////////////
// SC Welle
////////////////////////////////////////////////////////////

// OSX standalone: https://github.com/dathinaios/sc_osx_standalone
// App packer: https://sveinbjorn.org/platypus


/*
MIDI send as few vals as possible, only those that changed (pattern, eq, env).
Volume send with steps of 0.2
*/
/*
CC map, MIDI channel 1
Controller (max 120):
1-8     = pattern steps of tangible pins (CC0 off, CC>0 on)
9       = volume (CC map 0.0-1.0 -> 0-127)
10-14   = EQ 5 values
16-20   = Env 4 values

send chan:    1
receive chan: 2
*/

////////////////////////////////////////////////////////////
// Object for all
i = ();
// global vars
i.pattern = [1,0,0,0,0,0,0,0];
i.volume = 0.1;
i.envelope = [ [ 0, 0.1, 0.3, 1 ], [ 0, 1, 0.4, 0 ] ] ; // atk, dec, sus, rel
i.eq = [[0.0, 0.3, 0.7, 1.0], [0.5, 0.5, 0.5, 0.5]];
i.eqMidi = [ 0.5, 0.25, 0.52, 0.7, 0.5 ];
i.envMidi = [ 0.2, 0.15, 0.35, 0.64 ];
i.stringInput = 0;
i.selInst = [1, 1];
i.selPattern = [1, 1];
// conversions
i.volumeMap = ControlSpec.new(0, 126, \lin);  // CC 0-126
i.midiDevices = nil;

////////////////////////////////////////////////////////////
// START MIDI function
i.startMIDI = {
	MIDIClient.init;

	defer{
		i.midiPortsNum = MIDIClient.myoutports;
		i.midiDevices = Array.fill(i.midiPortsNum, nil);
		// i.popup.items.clear;
		i.popArr = Array.fill((i.midiPortsNum + 1), 1);
		i.popArr[0] = "connect to MIDI";
		MIDIClient.destinations.do({|d, c|
			c.post; d.device.post; d.name.post; d.uid.postln;
			i.midiDevices[c] = d;
			i.popArr[c+1] = d.device;
		});
		i.midiDevices.postln;
		i.popup.items = i.popArr;
		i.popup.action = { |menu|
			var index = menu.value - 1;
			if (index>=0, {
				[index, menu.value, menu.item].postln;
				if (i.midiOut == nil, {
					i.midiOut = MIDIOut.newByName(i.midiDevices[index].device,i.midiDevices[index].name);
					i.midiOut.noteOn(16, 60, 60);
					i.popup.items = ["MIDI:" + i.midiDevices[index].device];
					i.popup.background_(Color.green(0.7));  // only changes the look of displayed item
					MIDIIn.connect;
					MIDIIn.addFuncTo(\control, ~control);
				});
			});
		};
	};
};

////////////////////////////////////////////////////////////
// MIDI INPUT function
~control = { |src, chan, num, val|
	if (chan==2, {
		/*['> MIDIIn > control', chan,num,val].postln;*/
		if (num==9, {
			['MIDIIn volume', num, val].postln;
			i.volume = val/126;
			defer { i.updateWindow() };
		});
		if ((num>=1) && (num<=8), {
			var index = num-1;
			['MIDIIn pattern', num, val].postln;
			i.pattern[index] = val;
			defer { i.updateWindow() };

		});
		if ((num>=10) && (num<=14), {
			var index = num-10;
			['MIDIIn eq', num, val].postln;
			i.eqMidi[index] = val/100;
			['MIDIIn i.eqMidi', i.eqMidi].postln;
			i.eq = i.convertEq(i.eqMidi);
			defer { i.updateWindow() };
		});
		if ((num>=16) && (num<=19), {
			var index = num-16;
			['MIDIIn env', num, val].postln;
			i.envMidi[index] = val/100;
			['MIDIIn i.envMidi', i.envMidi].postln;
			i.envelope = i.convertEnv(i.envMidi);
			defer { i.updateWindow() };
		});
	})
};


////////////////////////////////////////////////////////////
i.sendMIDI = {|f, message|
	message.postln;
	if (i.midiOut != nil, {
		switch(message[0],
			'sendVolume', {
				i.midiOut.control(1, 9, message[1])
			},
			'sendPattern', {
				var chan = 1 + message[1];
				var val =  i.pattern[ message[1] ];
				i.midiOut.control(1, chan, val);
			},
			'sendEq', {
				var newEqMidi = message[1];
				var eqMidi = i.eqMidi;
				for (0, 4, {|c|
					var cc = c+10;  // midi control Eq = cc 10-14
					if (eqMidi[c] != newEqMidi[c], {  // check if eq changed, and only send changed values
						i.midiOut.control(1, cc, newEqMidi[c]*100);
					});

				});
				i.eqMidi = newEqMidi;
			},
			'sendEnv', {
				var newEnvMidi = message[1];
				var envMidi = i.envMidi;
				for (0, 3, {|c|
					var cc = c+16;  // midi control Env = cc 16-20
					if (envMidi[c] != newEnvMidi[c], {  // check if eq changed, and only send changed values
						i.midiOut.control(1, cc, newEnvMidi[c]*100);
					});

				});
				i.envMidi = newEnvMidi;
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
	// message.postln;
	switch (message[0],
		'setVolume', {
			if (i.volume != message[1], {
				i.sendMIDI(['sendVolume', i.volume]);
				i.volume = message[1];
			})
			// postf("set volume: %\n", i.volume);

		},
		'setPattern', {
			var c = message[1];
			if (i.pattern[c] == 0, {
				i.pattern[c] = 1;
			}, {
				i.pattern[c] = 0
			});
			defer { i.updateWindow() };
			i.sendMIDI(['sendPattern', c])
		},
		'setEq', {
			var midiEq;
			i.eq = message[1];
			midiEq = i.unConvertEq(i.eq);
			i.sendMIDI(['sendEq', midiEq]);
		},
		'setEnvelope', {
			var midiEnv;
			i.envelope = message[1];
			midiEnv = i.unConvertEnv(i.envelope);
			i.sendMIDI(['sendEnv', midiEnv]);
		},
		'changeInput', {
			if (i.stringInput == 0, {
				i.stringInput = 1;
				i.stringInputButton.states = [["Route Input to:\n\n Envelope", Color.grey, Color.white]];
			}, {
				i.stringInput = 0;
				i.stringInputButton.states = [["Route Input to:\n\n EQ", Color.grey, Color.white]];
			})
		},
		'setInstSelection', {
			message.postln;
		},
		'setPatternSelection', {
			message.postln;
		},
		{ postf("default: post message %\n", message); }
	);
};



////////////////////////////////////////////////////////////
// update Window function
i.updateWindow = {
	// ("update window").postln;
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
	i.window = Window.new("Tangible Signals - Welle MIDI emulation", Rect(10, 1910, 1130, 200))
	.front
	.background_(Color.white);


	////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////
	// interaction:
	i.upperHalfView = CompositeView(i.window, Rect(0,0,1200,80)).background_(Color.black);
	i.interactionRow = HLayoutView(i.upperHalfView, Rect(10,10,1100,60)).background_(Color.black);

	// make knob for selecting instruments
	////////////////////////////////////////////////////////////
	// spacer
	c = CompositeView(i.interactionRow, Rect(0, 0, 20, 30));
	// add volume knob
	i.selectInstrumentKnob = Knob(i.interactionRow, Rect(60, 10, 90, 90))
	.value_(0)
	.action_({|j|
		var val = (j.value*126).asInteger;
		if ((val % 10) == 0, {
			i.interactionGUI(['setInstSelection', val]);
		});
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
		var val = (j.value*126).asInteger;
		if ((val % 10) == 0, {
			i.interactionGUI(['setPatternSelection', val]);
		});
	});
	// spacer
	c = CompositeView(i.interactionRow, Rect(0, 0, 20, 30));
	// instrument index
	i.instIndex = StaticText.new(i.interactionRow, Rect(0, 0, 90, 60)).stringColor_(Color.white).string_("Pattern 1/1");


	////////////////////////////////////////////////////////////
	// start interaction button
	// i.midiStartButton = Button(i.interactionRow,Rect(0,0,100,10)).states_([["MIDI\n connect to IAC", Color.grey, Color.white]])
	// .action_({
	// 	i.startMIDI.value;
	// });
	// spacer
	c = CompositeView(i.interactionRow, Rect(0, 0, 380, 30));

	// string input choose
	i.stringInputButton = Button(i.interactionRow,Rect(0,0,100,10)).states_([["Route Input to:\n\n EQ", Color.grey, Color.white]])
	.action_({|b|
		i.interactionGUI(['changeInput'])
	});
	// spacer
	c = CompositeView(i.interactionRow, Rect(0, 0, 20, 30));

	// MIDI input choose
	i.popup = PopUpMenu(i.interactionRow, Rect(10, 10, 190, 20));
	i.popup.stringColor_(Color.black);   // only changes the look of displayed item
	i.popup.font_(Font("Courier", 13));   // only changes the look of displayed item







	////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////
	// layout for device elements
	i.row = HLayoutView(i.window, Rect(10,100,1100,70));
	////////////////////////////////////////////////////////////
	// add volume knob
	i.volumeKnob = Knob(i.row, Rect(60, 10, 80, 50))
	.value_(0.4)
	.action_({|j|
		var val = (j.value*126).asInteger;
		if ((val % 10) == 0, {
			i.interactionGUI(['setVolume', val]);
		});
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
	i.eqView = EnvelopeView(i.row, Rect(400, 0, 230, 50))
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
	.step_(0.05)
	.action_({|b|
		i.interactionGUI(['setEnvelope', b.value])
	})
	.thumbSize_(12)
	.value_([[0.0, 0.1, 0.5, 1.0],[0.0,1.0,0.8,0.0]]);

	// TEXTfor device elements
	i.rowTextView = HLayoutView(i.window, Rect(10,170,1100,30));
	c = CompositeView(i.rowTextView, Rect(0, 0, 20, 30));
	i.rowText1 = StaticText.new(i.rowTextView, Rect(0, 0, 80, 60)).stringColor_(Color.black).string_("Volume");
	c = CompositeView(i.rowTextView, Rect(0, 0, 140, 30));
	i.rowText2 = StaticText.new(i.rowTextView, Rect(0, 0, 80, 60)).stringColor_(Color.black).string_("Pattern");
	c = CompositeView(i.rowTextView, Rect(0, 0, 300, 30));
	i.rowText2 = StaticText.new(i.rowTextView, Rect(0, 0, 80, 60)).stringColor_(Color.black).string_("EQ");
	c = CompositeView(i.rowTextView, Rect(0, 0, 200, 30));
	i.rowText2 = StaticText.new(i.rowTextView, Rect(0, 0, 80, 60)).stringColor_(Color.black).string_("Envelope");

};



////////////////////////////////////////////////////////////
// Start process
i.makeWindow.value;
i.updateWindow.value;
i.startMIDI.value;


/*
MIDIIn.connect;
o = MIDIOut.newByName("IAC-Treiber", "Bus 1")
o.control(2, 9, 20); // volume
o.control(2, 3, 0);o.control(2, 5, 1); // pattern
o.control(2, 10, 40); // eq
o.control(2, 16, 41);o.control(2, 18, 21); // envelope
*/