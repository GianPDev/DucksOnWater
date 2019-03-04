package;

import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUIButton;
import flixel.addons.ui.FlxUIState;
import flixel.addons.ui.FlxUISubState;
import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.input.FlxInput;
import flixel.input.mouse.FlxMouseEventManager;
import flixel.input.keyboard.FlxKey;
import flixel.addons.ui.ButtonLabelStyle;
import flixel.text.FlxText;
import flixel.addons.ui.BorderDef;
import flixel.input.gamepad.FlxGamepad;
import flixel.group.FlxGroup;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

import flixel.addons.nape.*;
import nape.geom.Vec2;
import nape.phys.Body;
import nape.phys.BodyType;
import nape.shape.Polygon;
import nape.space.Space;
import nape.shape.Circle;
import nape.constraint.PivotJoint;
import nape.constraint.AngleJoint;
import nape.constraint.DistanceJoint;
import nape.constraint.LineJoint;
import nape.callbacks.CbEvent;
import nape.callbacks.CbType;
import nape.callbacks.InteractionCallback;
import nape.callbacks.InteractionListener;
import nape.callbacks.InteractionType;
import nape.dynamics.InteractionFilter;

class PlayState extends FlxUIState
{	
	public var uiCamera:FlxCamera;
	var gameCamera:FlxCamera;

	var btnHovering:Bool = false;
	var resetState:FlxUIButton;

	public var closedCaptions:FlxText;

	public var hand:PivotJoint;

	public var groupDucks:FlxTypedGroup<FlxNapeSprite>;
	var duckJump:FlxTimer;

	override public function create():Void
	{
		//FlxG.plugins.add(new FlxMouseEventManager());

		if(Main.tongue == null)
		{
			Main.tongue = new FireTongueEx();
			Main.tongue.init("en-US");
			FlxUIState.static_tongue = Main.tongue; //IMPORTANT Must change before it is created, as static variables cannot be changed after created?
		}

		gameCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		gameCamera.bgColor = 0xff6A8475;

		uiCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		uiCamera.bgColor = FlxColor.TRANSPARENT;
		
		FlxG.cameras.reset(gameCamera);
		FlxG.cameras.add(uiCamera);

		FlxCamera.defaultCameras = [gameCamera];
		
		super.create();


		groupDucks = new FlxTypedGroup();

		closedCaptions = new FlxText(16, FlxG.height - 64, FlxG.width, "", 8, false);
		closedCaptions.cameras = [uiCamera];
		closedCaptions.setFormat(null, 8, 0xFFFFFFFF, CENTER, OUTLINE_FAST, 0xFF000000, false);
		closedCaptions.text = "Ducks on Water" + " by " + "Gian P.";
		closedCaptions.size = 16;
		add(closedCaptions);

		resetState = new FlxUIButton(0, 0, _tongue.get("$RESET", "ui"));
		resetState.loadGraphicSlice9(null, 0, 0, null, FlxUI9SliceSprite.TILE_NONE, -1, true);
		resetState.name = "resetState";
		resetState.params = [0, "reset"];
		resetState.resize(32, 32);
		resetState.getLabel().text = _tongue.get("$RESET", "ui");
		resetState.getLabel().size = 16;
		resetState.getLabel().color = 0xFFEEEEEE;
		resetState.color = 0xFFAA0000;
		//add(resetState);

		var background:FlxSprite = new FlxSprite(0,0);
		background.loadGraphic("assets/images/background.png");
		background.immovable = true;
		background.solid = false;
		background.allowCollisions = FlxObject.NONE;
		add(background);

		FlxG.sound.playMusic("assets/music/AmbientBirds001.ogg", 1, true);

		FlxNapeSpace.init(); //creates a nape space for nape items to do physics in
		FlxNapeSpace.drawDebug = true;
		FlxNapeSpace.space.gravity.setxy(0, 1000);
		
		hand = new PivotJoint(FlxNapeSpace.space.world, FlxNapeSpace.space.world, new Vec2(), new Vec2());
		hand.stiff = false;
		hand.space = FlxNapeSpace.space;
		hand.active = false;

		var bodyWalls:Body = new Body(BodyType.STATIC);
		bodyWalls.shapes.add(new Polygon(Polygon.rect(20.0, 0.0, -40.0, FlxG.height))); //creates left wall
		bodyWalls.shapes.add(new Polygon(Polygon.rect(FlxG.width - 20.0, 0.0, 40.0, FlxG.height))); //creats right wall
		bodyWalls.shapes.add(new Polygon(Polygon.rect(0.0, 20.0, FlxG.width, -40.0))); //creates top wall
		bodyWalls.shapes.add(new Polygon(Polygon.rect(0.0, FlxG.height - 20.0, FlxG.width, 40.0))); //create bottom wall
		bodyWalls.space = FlxNapeSpace.space;

		//Water
		var fluidSprite:FlxNapeSprite = new FlxNapeSprite(0, 0); //constructing the sprite
		fluidSprite.destroyPhysObjects(); //destroyting exisiting nape stuff to add our own nape stuff
		fluidSprite.centerOffsets(false); //not sure what this does, it was part of a function I copied
		fluidSprite.body = new Body(BodyType.STATIC); //makes a new body and sets it to the sprite's body, in this case it's a static one (not affected by physics) - a container?
		var fluidShape:Polygon = new Polygon(Polygon.box(FlxG.width, 100.0)); //The actual physics body shape that does physics with other objects
		fluidShape.filter.collisionMask = 0; //Sets it to no collisions, but still "overlaps", I think nape uses the word sensor
		fluidShape.fluidEnabled = true;  //Fluid physics, make stuff float.
		fluidShape.filter.fluidMask = 2; //any other Body with the same fluidMask will do fluid stuff
		fluidShape.fluidProperties.density = 5;
		fluidShape.fluidProperties.viscosity = 10;
		fluidSprite.body.shapes.add(fluidShape);
		fluidSprite.makeGraphic(FlxG.width, 100, 0xFF5D8781);
		//fluidSprite.alpha = 0.7;
		fluidSprite.setPosition(fluidSprite.width / 2, FlxG.height - 50);
		fluidSprite.body.space = FlxNapeSpace.space;
		add(fluidSprite);

		
		for (i in 0...12) 
		{
			var nSprDuck:FlxNapeSprite = new FlxNapeSprite(0, 0);
			nSprDuck.destroyPhysObjects();
			nSprDuck.centerOffsets(false);
			nSprDuck.body = new Body(BodyType.DYNAMIC);
			nSprDuck.setPosition(FlxG.random.int(100, Math.floor(FlxG.width)), FlxG.height - 25);
			/*
			var circleShape:Circle = new Circle(20);
			circleShape.filter.collisionGroup = 1;
			circleShape.filter.sensorMask = 1;
			circleShape.filter.fluidGroup = 2; 
			nSprDuck.body.shapes.add(circleShape);
			nSprDuck.makeGraphic(40, 40, 0xFFFF0000);
			*/
			var pentagonShape:Polygon = new Polygon(Polygon.regular(20, 20, 6));
			pentagonShape.filter.collisionGroup = 2;
			pentagonShape.filter.fluidGroup = 2;
			pentagonShape.material.rollingFriction = 50;
			pentagonShape.material.dynamicFriction = 50;
			pentagonShape.material.density = 1;
			nSprDuck.body.shapes.add(pentagonShape);
			/*
			var headShape:Circle = new Circle(10);
			headShape.filter.collisionGroup = 1;
			headShape.filter.fluidGroup = 2;
			nSprDuck.body.shapes.add(headShape);
			nSprDuck.body.shapes.at(0).translate(new Vec2(-20, -15)); 
			*/
			nSprDuck.loadGraphic("assets/images/duck.png", 40, 30);
			var flip:Bool = FlxG.random.bool(i*10);
			if(flip == true)
				nSprDuck.flipX = true;
			nSprDuck.body.userData.data = nSprDuck;
			nSprDuck.body.space = FlxNapeSpace.space;
			//nSprDuck.body.allowRotation = false;
			groupDucks.add(nSprDuck);
			add(nSprDuck);

			var lineJoint = new LineJoint(fluidSprite.body, nSprDuck.body, new Vec2(-FlxG.width / 2, -50), new Vec2(0, 15), new Vec2(1, 0), 0, FlxG.width);
			lineJoint.stiff = false;
			//lineJoint.space = FlxNapeSpace.space;

		}
		

		/*
		for (i in 0...10) 
		{
			var pentagonBody:Body = new Body();
			pentagonBody.position.setxy(Math.random() * FlxG.width, Math.random() * FlxG.height);
			var pentagonShape:Polygon = new Polygon(Polygon.regular(25, 25, 5));

			pentagonShape.filter.collisionGroup = 2;
			pentagonShape.filter.fluidGroup = 2;

			pentagonShape.body = pentagonBody;
			pentagonBody.space = FlxNapeSpace.space;
		}*/

		duckJump = new FlxTimer().start(FlxG.random.float(1, 10), function(_)
		{
			groupDucks.forEachAlive(function(duck)
			{
				if(FlxG.random.bool(25))
				{
					trace("Duck Jumped: " + duck);
					duck.body.applyImpulse(new Vec2(FlxG.random.float(-150, 150), FlxG.random.float(-150, 150)));
				}
			});
		}, 0);
		
	}
	
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if(closedCaptions.alpha > 0) //if statement for constantly fading out text every frame
		{
			closedCaptions.alpha -= .005;
		}

		hand.anchor1.setxy(FlxG.mouse.x, FlxG.mouse.y);
		if(FlxG.mouse.justPressed)
		{
			//setCaptions("Left Clicked");
			var mp:Vec2 = new Vec2(FlxG.mouse.x, FlxG.mouse.y);
			for(i in 0...FlxNapeSpace.space.bodiesUnderPoint(mp).length)
			{
				var b:Body = FlxNapeSpace.space.bodiesUnderPoint(mp).at(i);
				if(!b.isDynamic()) continue;
					hand.body2 = b;
					hand.anchor2 = b.worldPointToLocal(mp);
					hand.active = true;
				break;
			}
		}
		else if (FlxG.mouse.justReleased)
		{
			hand.active = false;
		}



	}

	//overriding the getEvent function is for the FlxUIButtons and maybe other FlxUI stuff.
	public override function getEvent(event:String, target:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (params != null)
		{
			switch (event)
			{
				case "over_button":  btnHovering = true; trace("Button Hovering: " + btnHovering);
					switch(Std.string(params[1]))
					{
						case "toggle": "";
					}
				case "down_button": //a button is "down" when it is clicked, it does not have to be released on button
					switch(Std.string(params[1]))
					{
						case "rebind"	: "";
						case "up"		: "";
						case "down"		: "";
						case "left"		: "";
						case "right"	: "";
					}
				case "click_button": //click button and down button should be switched imo - click button is "clicked" when it is clicked and released over the button
					switch(Std.string(params[1]))
					{
						case "toggle" : "";
						case "reset": FlxG.resetState();
					}
				case "out_button": btnHovering = false; trace("Button Hovering: " + btnHovering); //When mouse is moved off from being over the button i.e Mouse that was over the button is no longer over that button
					switch (Std.string(params[1]))
					{
						case "toggle": "";
					}
				
			}
		}
	}

	function setCaptions(text:String):Void
	{
		closedCaptions.text = text;
		closedCaptions.alpha = 1;
	}
}
