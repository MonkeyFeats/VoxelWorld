#include "HumanCommon.as"
#include "Voxels.as"
#include "Vec3D.as"
//#include "AccurateSoundPlay.as"

void onInit( CBlob@ this )
{
	VoxelMap voxmap;
	this.set("voxmapInfo", @voxmap);	

	this.getShape().SetRotationsAllowed(false);
	this.getShape().SetStatic(true);

	this.Tag("player");	 

	this.set_f32("dir_x", 0.0f);
	this.set_f32("dir_y", 0.0f);

	this.set_f32("pos_x", 24.5f*8);	// world mid
	this.set_f32("pos_y", 23.0f*8); // 1 below sky max
	this.set_f32("pos_z", 24.5f*8); // world mid

	this.addCommandID(camera_sync_cmd);

	this.set_f32("cam rotation", 0.0f);
	this.set_f32("FOV", 10.5f);
	this.set_u8("CursorDist",5);
	
	this.SetMapEdgeFlags( u8(CBlob::map_collide_up) |
		u8(CBlob::map_collide_down) |
		u8(CBlob::map_collide_sides) );
	
	this.set_u32("menu time", 0);
	this.set_bool( "build menu open", false );
	this.set_string("last buy", "coupling");
	this.set_u32("groundTouch time", 0);
	this.set_bool( "onGround", true );
	this.getShape().getVars().onground = true;
}

void onTick( CBlob@ this )
{
	Move( this );		
	u32 gameTime = getGameTime();

	if (this.isMyPlayer())
	{
		ManageCamera(this);

		if ( gameTime % 10 == 0 )
		{
			this.set_bool( "onGround", this.isOnGround() );
			this.Sync( "onGround", false );
		}		
	}
}

Vec3f myPos(CBlob@ this)
{
	f32 x = this.get_f32("pos_x");
	f32 y =	this.get_f32("pos_y");
	f32 z =	this.get_f32("pos_z");
	return Vec3f(x,y,z);
}

void ManageCamera(CBlob@ this)
{
	//if(this.isMyPlayer() && getNet().isClient())
	//{
		CControls@ c = getControls();
		Driver@ d = getDriver();
		bool ctrl = c.isKeyJustPressed(KEY_LCONTROL);
		if(ctrl){ this.set_bool("stuck", !this.get_bool("stuck")); this.Sync("stuck", true);}
		if(!this.get_bool("stuck") && d !is null && c !is null && !c.isMenuOpened() && !getHUD().hasButtons() && !getHUD().hasMenus())
		{
			Vec2f ScrMid = Vec2f(f32(d.getScreenWidth()) / 2, f32(d.getScreenHeight()) / 2);
			Vec2f dir = (c.getMouseScreenPos() - ScrMid)/10;
			float dirX = this.get_f32("dir_x");
			float dirY = this.get_f32("dir_y");
			dirX += dir.x;
			dirY = Maths::Clamp(dirY-dir.y,-90,90);

			if (dirX > 360)
			dirX = 0;
			else if (dirX < 0)
			dirX = 360;

			this.set_f32("dir_x", dirX);
			this.set_f32("dir_y", dirY);
			c.setMousePosition(ScrMid);			
		}
		if(getGameTime() % 2 == 0)
		{
			SyncCamera(this);
		}
	//}
}

void Move( CBlob@ this )
{
	const bool myPlayer = this.isMyPlayer();
	const f32 camRotation = myPlayer ? getCamera().getRotation() : this.get_f32("cam rotation");
	const bool attached = this.isAttached();
	const bool up = this.isKeyPressed( key_up );
	const bool down = this.isKeyPressed( key_down );
	const bool left = this.isKeyPressed( key_left);
	const bool right = this.isKeyPressed( key_right );	
	const bool action1 = this.isKeyJustPressed( key_action1 );
	const bool action2 = this.isKeyJustPressed( key_action2 );
	const bool action3 = this.isKeyPressed( key_action3 );	
	const bool pickup = this.isKeyPressed( key_pickup );		
	const u32 time = getGameTime();
	f32 height = this.get_f32("pos_y");
	string currentTool = this.get_string( "current tool" );

	Vec3f playerPos = myPos(this); // fake pos

	if (myPlayer)
	{
		this.set_f32("cam rotation", camRotation);
		this.Sync("cam rotation", false);
	}

	VoxelMap@ voxmap;
	if (!this.get("voxmapInfo", @voxmap) || voxmap.chunks.length == 0)
	{
		return;
	}

	//voxmap.LoadChunks(playerPos, 16, 16);
	//voxmap.SetChunkVisiblity(playerPos, camRotation);

	//print("x "+int((aimpos.x-0.5)/8)+" y "+int((aimpos.y-0.5)/8)+" z "+Maths::Abs((-16-int((this.get_f32("aim_posZ")-0.5)/8))));	

	//u8 cd = this.get_u8("CursorDist");
	//if (voxmap.GetBlockAtPosition(int((aimpos.x-0.5)/8), Maths::Abs(-16-int((this.get_f32("aim_posZ")/2))-height)/8, int((aimpos.y-0.5)/8)) == 0)
	//{
	//	if (cd < 5)
	//	cd++;
	//	this.set_u8("CursorDist",cd);
	//}
	//else
	//{
	//	if (cd > 2)
	//	cd--;
	//	this.set_u8("CursorDist",cd);
	//}	

	f32 dir_x = this.get_f32("dir_x");
	f32 dir_y = this.get_f32("dir_y");

	int state = 0;
	Vec3i hit_pos = Vec3i();
	Vec3i pos_before_hit = Vec3i();
	Vec3f ray_pos = playerPos/8;
	ray_pos.y += 1.0f;
	Vec3f look_dir( Maths::Sin((dir_x)*Maths::Pi/180)*Maths::Cos(dir_y*Maths::Pi/180),
                    Maths::Sin(dir_y*Maths::Pi/180),
                    Maths::Cos((dir_x)*Maths::Pi/180)*Maths::Cos(dir_y*Maths::Pi/180));
	Raycast_precise(@voxmap, ray_pos, look_dir, 5, state, hit_pos, pos_before_hit);		

	if (state == 1)
	{
		voxmap.rx = hit_pos.x;
		voxmap.ry = hit_pos.y-1.0f;
		voxmap.rz = hit_pos.z; 

		if (action1)
		{
		    voxmap.SetBlockAt(Vec3i(pos_before_hit.x, pos_before_hit.y, pos_before_hit.z), 1);	    
		    pos_before_hit = hit_pos;
		    int offset = Maths::Min(int(pos_before_hit.z)+int(pos_before_hit.x)*8+8*8*int(pos_before_hit.y), 8-1);
		    //voxmap.chunks[offset].RebuildVoxelChunk();
		}
		else if (action2)
		{		    	
		    voxmap.SetBlockAt(Vec3i(hit_pos.x, hit_pos.y, hit_pos.z), 0);	    
		    pos_before_hit = hit_pos;
		    int offset = Maths::Min(int(hit_pos.z)+int(hit_pos.x)*8+8*8*int(hit_pos.y), 8-1);
		    //voxmap.chunks[offset].RebuildVoxelChunk();
		}
	}

	// move
	Vec2f moveVel(-1,-1);		

	int px = (playerPos.x/8);
	int py = (playerPos.y/8);
	int pz = (playerPos.z/8);	

	if (up && !down )  		 { moveVel.y = -3.5f; }	
	else if ( down && !up )  { moveVel.y =  3.5f; }	
	else {moveVel.y=0;}

	if ( right && !left ) 	 { moveVel.x = -3.5f; }
	else if (left && !right ){ moveVel.x =  3.5f; }
	else {moveVel.x=0;}

	moveVel.RotateBy( -this.get_f32("dir_x") );

	this.set_f32("pos_x", playerPos.x-moveVel.x);
	this.set_f32("pos_z", playerPos.z-moveVel.y);
	
//	Vec2f velPos((pos.x-moveVel.x), (pos.y-moveVel.y));
//
//	if (voxmap.isOverlapping( Vec3i(velPos.x/8.0f, py, pz), Vec3i(px, py, pz)) ) 
//    moveVel.x = 0;
//
//    if (voxmap.isOverlapping( Vec3i(px, py, velPos.y/8.0f), Vec3i(px, py, pz)) )
//    moveVel.y = 0; 
//	
//
//	bool falling = (!(voxmap.isOverlapping( Vec3i(px, py-1, velPos.y/8.0f), Vec3i(px, py, pz)) || voxmap.isOverlapping( Vec3i(velPos.x/8.0f, py-1, pz), Vec3i(px, py, pz))));
//	f32 jumptimer = this.get_f32("jump timer");
//	bool jumping = this.get_bool("jumping");
//	if ( action3 && !jumping && !falling ) 
//	{ 
//		this.set_bool("jumping", true);
//	}
//	else if (jumping)
//	{
//		jumptimer++;
//		height+=2.5-(jumptimer/4);				
//		if(jumptimer == 12.0)
//		{
//			jumptimer = 0;
//			this.set_bool("jumping", false);
//		}
//		
//		this.set_f32("jump timer", jumptimer);
//	}
//	else if (falling && !this.get_bool("stuck"))

	if ( action3 )
	{
		height+=1.5; 
	}
	else if ( pickup )
	{ height-=1.5; }
	
	this.set_f32("pos_y", height);
}

void Raycast_precise(VoxelMap@ voxmap, Vec3f ray_pos, Vec3f ray_dir, int max_dist, int &out state, Vec3i &out hit_pos, Vec3i &out pos_before_hit)
{
    Vec3i ray_world_pos = Vec3i(int(ray_pos.x), int(ray_pos.y), int(ray_pos.z));
    Vec3i delta_dist = Vec3i(Maths::Abs(1/(ray_dir.x+0.00001)), Maths::Abs(1/(ray_dir.y+0.00001)), Maths::Abs(1/(ray_dir.z+0.00001)));
    Vec3i side_dist;
    Vec3i step;
    if(ray_dir.x < 0)
    {
        step.x = -1;
        side_dist.x = (ray_pos.x - ray_world_pos.x) * delta_dist.x;
    }
    else
    {
        step.x = 1;
        side_dist.x = (ray_world_pos.x + 1.0f - ray_pos.x) * delta_dist.x;
    }
    if(ray_dir.y < 0)
    {
        step.y = -1;
        side_dist.y = (ray_pos.y - ray_world_pos.y) * delta_dist.y;
    }
    else
    {
        step.y = 1;
        side_dist.y = (ray_world_pos.y + 1.0f - ray_pos.y) * delta_dist.y;
    }
    if(ray_dir.z < 0)
    {
        step.z = -1;
        side_dist.z = (ray_pos.z - ray_world_pos.z) * delta_dist.z;
    }
    else
    {
        step.z = 1;
        side_dist.z = (ray_world_pos.z + 1.0f - ray_pos.z) * delta_dist.z;
    }
    while(max_dist > 0)
    {
        pos_before_hit = ray_world_pos;
        if(side_dist.x < side_dist.y)
        {
            if(side_dist.x < side_dist.z)
            {
                side_dist.x += delta_dist.x;
                ray_world_pos.x += step.x;
                if(ray_world_pos.x > WorldSize.x*ChunkSize || ray_world_pos.x < 0)
                {
                    //print("oob on x side");
                    state = 3;
                    return;
                }
            }
            else
            {
                side_dist.z += delta_dist.z;
                ray_world_pos.z += step.z;
                if(ray_world_pos.z > WorldSize.z*ChunkSize || ray_world_pos.z < 0)
                {
                    //print("oob on z side");
                    state = 3;
                    return;
                }
            }
        }
        else
        {
            if(side_dist.y < side_dist.z)
            {
                side_dist.y += delta_dist.y;
                ray_world_pos.y += step.y;
                if(ray_world_pos.y > WorldSize.y*ChunkSize || ray_world_pos.y < 0)
                {
                    //print("oob on y side");
                    state = 3;
                    return;
                }
            }
            else
            {
                side_dist.z += delta_dist.z;
                ray_world_pos.z += step.z;
                if(ray_world_pos.z > WorldSize.z*ChunkSize || ray_world_pos.z < 0)
                {
                    //print("oob on z side");
                    state = 3;
                    return;
                }
            }
        }  

        u8 check = voxmap.GetBlockAtPosition(Vec3i(ray_world_pos.x, ray_world_pos.y, ray_world_pos.z));
        if(check != 0)
        {
            //print("hit something");
            state = 1;
            hit_pos = ray_world_pos;
            
            //pos_before_hit = ray_world_pos;
            return;
        }
        max_dist--;
    }

    
    //print("too far");
    state = 2;
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}

void onCommand( CBlob@ this, u8 cmd, CBitStream @params )
{
	if (cmd == this.getCommandID(camera_sync_cmd))
	{
		HandleCamera(this, params, !canSend(this));
	}
}

void onAttached( CBlob@ this, CBlob@ attached, AttachmentPoint @attachedPoint )
{
	this.ClearMenus();
}