#include "RenderConsts.as"
#include "Vec3D.as"

const string tiltex_name = "TileTextures.png";
const Vec3i WorldSize(8,8,8); // world size in chunks
const u8 VisibiltyScale = 3; // chunks visible from player pos // not implemented
const u8 ChunkSize = 8; // voxels per chunk cubed 8*8*8
const float tUnit = 0.125f; //texture unit
const u8 WaterLevel = 12;

namespace Block
{
	enum Type 
	{
		None = 0,
		Bricks,
		Stone,
		GrassyDirt,
		GrassTop,
		Dirt,
		Water			
	};

	bool isOpaque( const uint blockType ) { return (blockType >= 1 && blockType <= 5); } // doesn't pass light through
	bool isSolid( const uint blockType ) { return (blockType >= 1 && blockType <= 4); }
	bool isWater( const uint blockType ) { return (blockType == 6); } 
	//bool isLava( const uint blockType ) { return (blockType >= 28 && blockType <= 30); }
}

const Vec3i[] offsets = 
{
	Vec3i( 0, 1, 0), // up
	Vec3i( 0, 0, 1), // north
	Vec3i( 1, 0, 0), // east
	Vec3i( 0, 0,-1), // south
	Vec3i(-1, 0, 0), // west
	Vec3i( 0,-1, 0)  // down
};

enum Direction
{
	Up = 0,
	North,
	East,
	South,
	West,
	Down,
};

class LightQueue
{	
	Vec3i[] queuedPositions;
	int val;
};

class MapData
{
	int[][][] data;
	int[][][] lightMap;

	LightQueue bfsQueue;

	MapData(){}

	int to1D( int x, int y, int z ) 
	{
    	return (z * WorldSize.x * WorldSize.y) + (y * WorldSize.x) + x;
	}
	Vec3i to3D( int idx )
	{
	    int z = idx / (WorldSize.x * WorldSize.y);
	    idx -= (z * WorldSize.x * WorldSize.y);
	    int y = idx / WorldSize.x;
	    int x = idx % WorldSize.x;
	    return Vec3i(x, y, z);
	}

	void SaveWorld()
	{
		string s = CFileMatcher("VoxelWorld"+".cfg").getFirst();

		ConfigFile cfg = ConfigFile(s);

		for (int x = 0; x < WorldSize.x*ChunkSize; ++x) 
		{	
			for (int y = 0; y < WorldSize.y*ChunkSize; ++y) 
			{		
				for (int z = 0; z < WorldSize.z*ChunkSize; ++z) 
				{
					s32 place = to1D(x,y,z);
					cfg.add_s32("data_"+place, data[x][y][z]);
					cfg.add_s32("light_"+place, lightMap[x][y][z]);
				}	
			}
		}

		cfg.saveFile("VoxelWorld.cfg");
		
	}

	void LoadWorld()
	{
		string s = "../Cache/VoxelWorld.cfg";
		ConfigFile cfg = ConfigFile(s);

		if (cfg.loadFile(s))
		{
			for (uint x = 0; x < WorldSize.x*ChunkSize; ++x) 
			{	
				for (uint y = 0; y < WorldSize.y*ChunkSize; ++y) 
				{		
					for (uint z = 0; z < WorldSize.z*ChunkSize; ++z) 
					{
						int place = to1D(x,y,z);
						int loaddata = cfg.read_s32("data_"+place);
						data[x][y][z] = loaddata;
						int lightdata = cfg.read_s32("light_"+place);
						lightMap[x][y][z] = loaddata;
					}	
				}
			}
		}		
	}


	void GenerateTerrainData()
	{			
		data.clear();
		lightMap.clear();
		bfsQueue.queuedPositions.clear();

		Random rnd(getGameTime());
		Noise@ map_noise = Noise(153242341);

		for (uint pass = 0; pass <= 5; pass++) 
		{
			if (pass == 0) //terrain
			{
				data.set_length(WorldSize.x*ChunkSize);
				lightMap.set_length(WorldSize.x*ChunkSize);
				for (uint x = 0; x < WorldSize.x*ChunkSize; ++x) 
				{	
					data[x].set_length(WorldSize.x*ChunkSize);
					lightMap[x].set_length(WorldSize.x*ChunkSize);
					for (uint y = 0; y < WorldSize.x*ChunkSize; ++y) 
					{		
						data[x][y].set_length(WorldSize.x*ChunkSize);
						lightMap[x][y].set_length(WorldSize.x*ChunkSize);
						for (uint z = 0; z < WorldSize.x*ChunkSize; ++z) 
						{	
							int height = (map_noise.Fractal((x + getGameTime()) * 0.005, (z + getGameTime()) * 0.005) * 30);	
							 // setting the Block Type
							if (height >= y+4)
							{
								data[x][y][z] = Block::Stone;
							}	
							else if (height >= y+2)
							{
								data[x][y][z] = Block::Dirt;  
							}	
							else if (height > y)
							{
								if (XORRandom(24) == 0)
								data[x][y][z] = Block::Stone;

								else if (XORRandom(28) == 0)
								data[x][y][z] = Block::Dirt;
								
								else
								data[x][y][z] = Block::GrassyDirt;						
							}
							else
							{
								data[x][y][z] = Block::None; 
							}
						}	
					}
				}
			}
			else if (pass == 1) // water
			{
				for (uint x = 0; x < WorldSize.x*ChunkSize; ++x) 
				{	
					for (uint y = 0; y < WorldSize.x*ChunkSize; ++y) 
					{		
						for (uint z = 0; z < WorldSize.x*ChunkSize; ++z) 
						{	

							if (y <= WaterLevel && data[x][y][z] == Block::None)
							data[x][y][z] = Block::Water; 
						}
					}
				}
			}
			else if (pass == 2) // caves
			{
				//void CarveCaves() 
				{
					int cavesCount = 8;//blocks.Length / 8192;
					float caveRadius = 3.0;
					
					for (int i = 0; i < cavesCount; i++) 
					{
						//int CurrentProgress = float(i) / cavesCount;
						double caveX = rnd.NextRanged(WorldSize.x*ChunkSize);
						double caveY = rnd.NextRanged(WorldSize.x*ChunkSize);
						double caveZ = rnd.NextRanged(WorldSize.x*ChunkSize);
						
						int caveLen = int(rnd.NextFloat() * rnd.NextFloat() * 200)*20;
						double theta = rnd.NextFloat() * 4 * Maths::Pi, deltaTheta = 0;
						double phi = rnd.NextFloat() * 4 * Maths::Pi, deltaPhi = 0;
						
						for (int j = 0; j < caveLen; j++) 
						{
							caveX += Maths::Sin(theta) * Maths::Cos(phi);
							caveZ += Maths::Cos(theta) * Maths::Cos(phi);
							caveY += Maths::Sin(phi);
							
							theta = theta + deltaTheta * 0.2;
							deltaTheta = deltaTheta * 0.9 + (rnd.NextFloat() - rnd.NextFloat());
							phi = phi / 2 + deltaPhi / 4;
							deltaPhi = deltaPhi * 0.95 + (rnd.NextFloat() - rnd.NextFloat());
							//if (rnd.NextFloat() < 0.25) continue;
							
							int cenX = int(caveX + (rnd.NextRanged(3) - 1.5));
							int cenY = int(caveY + (rnd.NextRanged(3) - 1.5));
							int cenZ = int(caveZ + (rnd.NextRanged(3) - 1.5));
							
							double radius = ((WorldSize.y) - cenY) / double(WorldSize.y);
							radius = (caveRadius * rnd.NextFloat())+1.0;
							//radius = radius * (Maths::Sin(j * Maths::Pi / caveLen)*0.5);
							FillOblateSpheroid(cenX, cenY, cenZ, float(radius), Block::None);
						}
					}
				}
			}
			//else if (pass == 3){}// flood lava
			//else if (pass == 4){}// spawn ores
			//else if (pass == 5) // spawn flora
			//{
				//void PlantTrees() 
				//{
				//	int numPatches = Width * Length / 4000;
				//	//CurrentState = "Planting trees";
				//	
				//	for (int i = 0; i < numPatches; i++) {
				//		//CurrentProgress = (float)i / numPatches;
				//		int patchX = rnd.Next(Width), patchZ = rnd.Next(Length);
				//		
				//		for (int j = 0; j < 20; j++) {
				//			int treeX = patchX, treeZ = patchZ;
				//			for (int k = 0; k < 20; k++) {
				//				treeX += rnd.Next(6) - rnd.Next(6);
				//				treeZ += rnd.Next(6) - rnd.Next(6);
				//				if (treeX < 0 || treeZ < 0 || treeX >= Width ||
				//				    treeZ >= Length || rnd.NextFloat() >= 0.25)
				//					continue;
				//				
				//				int treeY = heightmap[treeZ * Width + treeX] + 1;
				//				if (treeY >= Height) continue;
				//				int treeHeight = 5 + rnd.Next(3);
				//				
				//				int index = (treeY * Length + treeZ) * Width + treeX;
				//				BlockRaw blockUnder = treeY > 0 ? blocks[index - oneY] : Block.Air;
				//				
				//				if (blockUnder == Block.Grass && CanGrowTree(treeX, treeY, treeZ, treeHeight)) {
				//					GrowTree(treeX, treeY, treeZ, treeHeight);
				//				}
				//			}
				//		}
				//	}
				//}
			//}			
		}		
	}

	void FillOblateSpheroid(int x, int y, int z, float radius, u8 block) 
	{
		int xStart = Maths::Floor(Maths::Max(x - radius, 0));
		int xEnd =   Maths::Floor(Maths::Min(x + radius, (WorldSize.x*ChunkSize) - 1));
		int yStart = Maths::Floor(Maths::Max(y - radius, 0));
		int yEnd =   Maths::Floor(Maths::Min(y + radius, (WorldSize.y*ChunkSize) - 1));
		int zStart = Maths::Floor(Maths::Max(z - radius, 0));
		int zEnd =   Maths::Floor(Maths::Min(z + radius, (WorldSize.z*ChunkSize) - 1));
		float radiusSq = radius * radius;
		
		for (int yy = yStart; yy <= yEnd; yy++)
			for (int zz = zStart; zz <= zEnd; zz++)
				for (int xx = xStart; xx <= xEnd; xx++)
		{
			int dx = xx - x, dy = yy - y, dz = zz - z;
			if ((dx * dx + 2 * dy * dy + dz * dz) < radiusSq) {
				int index = (yy * 8 + zz) * 8 + xx;
				//if (data[x][y][z] == Block::Stone)
				if (xx > 0 && yy > 0 && zz > 0 && xx < (WorldSize.x*ChunkSize) && yy < (WorldSize.y*ChunkSize) && zz < (WorldSize.z*ChunkSize))
					data[xx][yy][zz] = block;
			}
		}
	}
/*
	bool CanGrowTree(int treeX, int treeY, int treeZ, int treeHeight) 
	{
		// check tree base
		int baseHeight = treeHeight - 4;
		for (int y = treeY; y < treeY + baseHeight; y++)
			for (int z = treeZ - 1; z <= treeZ + 1; z++)
				for (int x = treeX - 1; x <= treeX + 1; x++)
		{
			if (x < 0 || y < 0 || z < 0 || x >= Width || y >= Height || z >= Length)
				return false;
			int index = (y * Length + z) * Width + x;
			if (blocks[index] != 0) return false;
		}
		
		// and also check canopy
		for (int y = treeY + baseHeight; y < treeY + treeHeight; y++)
			for (int z = treeZ - 2; z <= treeZ + 2; z++)
				for (int x = treeX - 2; x <= treeX + 2; x++)
		{
			if (x < 0 || y < 0 || z < 0 || x >= Width || y >= Height || z >= Length)
				return false;
			int index = (y * Length + z) * Width + x;
			if (blocks[index] != 0) return false;
		}
		return true;
	}
	
	void GrowTree(int treeX, int treeY, int treeZ, int height) {
		int baseHeight = height - 4;
		int index = 0;
		
		// leaves bottom layer
		for (int y = treeY + baseHeight; y < treeY + baseHeight + 2; y++)
			for (int zz = -2; zz <= 2; zz++)
				for (int xx = -2; xx <= 2; xx++)
		{
			int x = xx + treeX, z = zz + treeZ;
			index = (y * Length + z) * Width + x;
			
			if (Math.Abs(xx) == 2 && Math.Abs(zz) == 2) {
				if (rnd.NextFloat() >= 0.5)
					blocks[index] = Block.Leaves;
			} else {
				blocks[index] = Block.Leaves;
			}
		}
		
		// leaves top layer
		int bottomY = treeY + baseHeight + 2;
		for (int y = treeY + baseHeight + 2; y < treeY + height; y++)
			for (int zz = -1; zz <= 1; zz++)
				for (int xx = -1; xx <= 1; xx++)
		{
			int x = xx + treeX, z = zz + treeZ;
			index = (y * Length + z) * Width + x;

			if (xx == 0 || zz == 0) {
				blocks[index] = Block.Leaves;
			} else if (y == bottomY && rnd.NextFloat() >= 0.5) {
				blocks[index] = Block.Leaves;
			}
		}
		
		// then place trunk
		index = (treeY * Length + treeZ) * Width + treeX;
		for (int y = 0; y < height - 1; y++) {
			blocks[index] = Block.Log;
			index += oneY;
		}
	}
*/

	int GetCellType(int x, int y, int z) { return data[x][y][z]; }
	u8 GetCellLight(int x, int y, int z) { return getTorchlight(x,y,z); }
	Vec3i GetNeighborPos(int x, int y, int z, u8 dir)
	{
		Vec3i offsetToCheck = offsets[dir];
		Vec3i neighborCoord = Vec3i(x + offsetToCheck.x, y + offsetToCheck.y, z + offsetToCheck.z);
		if (neighborCoord.x < 0 || neighborCoord.x >= WorldSize.x*ChunkSize  || 
			neighborCoord.y < 0 || neighborCoord.y >= WorldSize.y*ChunkSize || 
			neighborCoord.z < 0 || neighborCoord.z >= WorldSize.z*ChunkSize  ) 
		{ return Vec3i(0,0,0); } 		
		else 		
		return neighborCoord;
	}
	int GetNeighbor(int x, int y, int z, u8 dir)
	{
		Vec3i offsetToCheck = offsets[dir];
		Vec3i neighborCoord = Vec3i(x + offsetToCheck.x, y + offsetToCheck.y, z + offsetToCheck.z);

		if (neighborCoord.x < 0 || neighborCoord.x >= WorldSize.x*ChunkSize  || 
			neighborCoord.y < 0 || neighborCoord.y >= WorldSize.y*ChunkSize || 
			neighborCoord.z < 0 || neighborCoord.z >= WorldSize.z*ChunkSize  ) 
		{ return 0; } 		
		else 
		{ return GetCellType(neighborCoord.x, neighborCoord.y, neighborCoord.z); }
	}
	int GetNeighborLight(int x, int y, int z, u8 dir)
	{
		Vec3i offsetToCheck = offsets[dir];
		Vec3i neighborCoord = Vec3i(x + offsetToCheck.x, y + offsetToCheck.y, z + offsetToCheck.z);

		if (neighborCoord.x < 0 || neighborCoord.x >= WorldSize.x*ChunkSize || 
			neighborCoord.y < 0 || neighborCoord.y >= WorldSize.y*ChunkSize || 
			neighborCoord.z < 0 || neighborCoord.z >= WorldSize.z*ChunkSize  ) 
		{ return 0; } 		
		else 
		{ return GetCellLight( neighborCoord.x, neighborCoord.y, neighborCoord.z); }
	}
	// Get the bits XXXX0000
	int getSunlight(int x, int y, int z) {
	    return (lightMap[x][y][z] >> 4) & 0xF;
	}
	// Set the bits XXXX0000
	void setSunlight(int x, int y, int z, int val) {
	    lightMap[x][y][z] = (lightMap[x][y][z] & 0xF) | (val << 4);
	    //QueueChunkUpdateAt(x,y,z);
	}
	// Get the bits 0000XXXX
	int getTorchlight(int x, int y, int z) {
	    return lightMap[x][y][z] & 0xF;
	}
	// Set the bits 0000XXXX
	void setTorchlight(int x, int y, int z, u8 val) {
	    lightMap[x][y][z] = (lightMap[x][y][z] & 0xF0) | val;
   		bfsQueue.queuedPositions.push_back(Vec3i(x,y,z));
	    //QueueChunkUpdateAt(x,y,z);
	}
};

class VoxelMap
{
	MapData mapData();
	VoxelChunk[] chunks();
	int[] chunksUpdateQueue;

	int rx;
	int ry; 
	int rz;

	VoxelMap() {
		MapData md();
		mapData = md;
	}

	void SaveWorld()
	{
		mapData.SaveWorld();
	}

	void LoadWorld()
	{
		mapData.LoadWorld();
		for (int x = 0; x < WorldSize.x*ChunkSize; x+=ChunkSize)
		{
			for (int y = 0; y < WorldSize.y*ChunkSize; y+=ChunkSize)
			{
				for (int z = 0; z < WorldSize.z*ChunkSize; z+=ChunkSize)
				{
					QueueChunkUpdateAt(Vec3i(x,y,z));
				}
			}
		}	
	}

	void Update()
	{
		LightQueue@ q = mapData.bfsQueue;
		while(!q.queuedPositions.empty()) 
		{
			// Get a reference to the front of the queue.
	    	Vec3i pos = q.queuedPositions[q.queuedPositions.get_length()-1]; 
  	
    		// Grab the light level of the current node    
	        int lightLevel = mapData.getTorchlight(pos.x, pos.y, pos.z);

	        if (lightLevel > 0)
	        {
	        	for (int i = 0; i < 6; i++)
				{	
					Vec3i npos = mapData.GetNeighborPos( pos.x, pos.y, pos.z, i);
					// check if neighbour voxel can pass light through

					//if(mapData.GetNeighbor( npos.x, npos.y, npos.z, i) == Block::None) //you want to do this, but its acting weird for me :C
					{	
						// Neighbours light level is 2 below this position
					    if (mapData.getTorchlight( npos.x,npos.y,npos.z) <= lightLevel-2) 
					    {
					    	// Set neighbour light level					    	
					        mapData.setTorchlight( npos.x,npos.y,npos.z, lightLevel - 1);				        
					        QueueChunkUpdateAt(Vec3i(npos.x,npos.y,npos.z));
					    }
					}				
				} 
	        }     	
	        
			//remove this queue postion
			q.queuedPositions.pop_back();

	    } //end - used up all the light(levels)	    

		while (!chunksUpdateQueue.empty())
		{			
			int num = chunksUpdateQueue[0];
			//print("num "+num);
			chunksUpdateQueue.removeAt(0);
			chunks[num].RebuildVoxelChunk();
			//chunks[to1D(chunkPos.x/ChunkSize,chunkPos.y/ChunkSize,chunkPos.z/ChunkSize)].RebuildVoxelChunk();
		}
	}

	void GenerateWorld()
	{
		mapData.GenerateTerrainData();	

		chunks.clear();	
		chunks.set_length(WorldSize.x*WorldSize.y*WorldSize.z);

		for(int x = 0; x < WorldSize.x; x++)
        {
            for(int y = 0; y < WorldSize.y; y++)
            {
                for(int z = 0; z < WorldSize.z; z++)
                {                    
                    VoxelChunk chunk(this, x,y,z);		
					chunks[to1D(x,y,z)] = chunk;
                }
            }
        }
	}

	int to1D( int x, int y, int z ) 
	{
    	return (x * WorldSize.x * WorldSize.y) + (y * WorldSize.x) + z;
	}

	Vec3i to3D( int idx )
	{
	    int z = idx / (WorldSize.x * WorldSize.y);
	    idx -= (z * WorldSize.x * WorldSize.y);
	    int y = idx / WorldSize.x;
	    int x = idx % WorldSize.x;
	    return Vec3i(x, y, z);
	}	

	void SetChunkVisiblity(Vec3i playerPos, f32 Angle)
	{ 
		Vec3i cPos(int((playerPos.x/ChunkSize)/8),int((playerPos.y/ChunkSize)/8),int((playerPos.z/ChunkSize)/8));
		if (cPos.x >= WorldSize.x || cPos.y >= WorldSize.y || cPos.z >= WorldSize.z)
		return;

	   for(int x=0; x <= 8; x++)
		{
			for(int y=0; y <= 4; y++)
  			{
	  			for(int z=0; z <= 8; z++)
	  			{
					Vec3i dist(int((cPos.x-4) + x), int((cPos.y-2) + y), int((cPos.z-4) + z));
	  				if ((dist.x >= WorldSize.x || dist.y >= WorldSize.y || dist.z >= WorldSize.z) || (dist.x < 0 || dist.y < 0 || dist.z < 0) )
					continue;			

					if (x > 0 && y > 0 && z > 0 && x < 8 && y < 4 && z < 8)
	  				{
	   					if (!chunks[to1D(dist.x,dist.y,dist.z)].visible)
	   					{
	   					  	LoadChunkAt(Vec3i(dist.x,dist.y,dist.z));
	   					}
	  				}
	  				else //if(distx > 1 || disty > 1 || distz > 1)
	  				{
	   					if (chunks[to1D(dist.x,dist.y,dist.z)].visible)
	   					{
	   					  	unLoadChunkAt(Vec3i(dist.x,dist.y,dist.z));
	   					}
	  				}
	   			}
	   		}
	   	}
	}	

	bool isOverlapping(Vec3i wPos, Vec3i voxPos)
	{
		int blockType = GetBlockAtPosition(wPos);
		if (blockType == 0)	
		return false;

		const f32 extents = 4.0f;

		if (voxPos.x > wPos.x+extents || voxPos.x < wPos.x-extents || voxPos.z > wPos.z+extents || voxPos.z < wPos.z-extents) return false;
		return true;
	}

	int GetBlockAtPosition(Vec3i wPos)
	{ 		
		if (wPos.x >= WorldSize.x*ChunkSize || wPos.y >= WorldSize.y*ChunkSize || wPos.z >= WorldSize.z*ChunkSize)
		return -1;	// forcing the player to stay in bounds you shouldnt need this check.

		int voxelNumX = wPos.x;
		int voxelNumY = wPos.y;
		int voxelNumZ = wPos.z;

		u16 blockType = mapData.GetCellType(voxelNumX, voxelNumY, voxelNumZ);
		return blockType; 
	}	

	void SetBlockAt(Vec3i wPos, u8 blockType) 
	{	  
		if (wPos.x >= WorldSize.x*ChunkSize || wPos.y >= WorldSize.y*ChunkSize || wPos.z >= WorldSize.z*ChunkSize ||
			wPos.x < 0 || wPos.y < 0 || wPos.z < 0)
		return;	
	 	mapData.data[wPos.x][wPos.y][wPos.z] = blockType;
	 	u8 lightLevel = 8;	 	
	 	mapData.setTorchlight(wPos.x, wPos.y, wPos.z, lightLevel);		

	 	QueueChunkUpdateAt(Vec3i(wPos.x,wPos.y,wPos.z));
	}	

	void QueueChunkUpdateAt(Vec3i wPos)
	{ 	 	 
		int x = wPos.x/ChunkSize;
		int y = wPos.y/ChunkSize;
		int z = wPos.z/ChunkSize;
		if ( chunksUpdateQueue.find(to1D(x,y,z)) == -1 )
		chunksUpdateQueue.push_back(to1D(x,y,z));
	 	//chunks[to1D(chunkPos.x/ChunkSize,chunkPos.y/ChunkSize,chunkPos.z/ChunkSize)].RebuildVoxelChunk();
	 	//chunks[to1D(chunkPos.x/ChunkSize,chunkPos.y/ChunkSize,chunkPos.z/ChunkSize)].visible = true; // probs going to have problems in multiplayer		
	}

	void LoadChunkAt(Vec3i chunkPos) { chunks[to1D(chunkPos.x,chunkPos.y,chunkPos.z)].visible = true; }
	void unLoadChunkAt(Vec3i chunkPos) { chunks[to1D(chunkPos.x,chunkPos.y,chunkPos.z)].visible = false; }

	void RenderCursor(Vec3f pos, float[] model)
	{		
		Render::SetBackfaceCull(true);
		Matrix::MakeIdentity(model);			
		Matrix::SetTranslation(model, (rx)-pos.x+0.5, (ry)-pos.y, (rz)-pos.z+0.5);
		Matrix::SetScale(model, 1.03, 1.03, 1.03);		
		Render::SetModelTransform(model);
		Render::RawTrianglesIndexed( "BlockOutlineWhite.png", wall_Vertexes, wall_IDs);
	}	

	void RenderWorld(Vec3f pos, float[] model)
	{
		//print("x"+chunks[0].get_length());
		for (int i=0; i < chunks.get_length(); i++)
		{
		  	//if (chunks[i].visible)
		  	chunks[i].Render(pos, model);
		}
	}
}

class VoxelChunk
{
	VoxelMap@ map;

	Vertex[] chunk_Vertexes;
	u16[] chunk_IDs;

	int Cx; int Cy; int Cz;	
	bool visible;
	int faceCount;			

	VoxelChunk(VoxelMap@ _map, int x, int y, int z)
	{
		@map = _map;
		Cx = x*ChunkSize;
		Cy = y*ChunkSize;
		Cz = z*ChunkSize;
	
		RebuildVoxelChunk();
	}	

	int to1D( int x, int y, int z ) { return (z * ChunkSize * ChunkSize) + (y * ChunkSize) + x; }

	Vec3i to3D( int idx )
	{
	    int z = idx / (ChunkSize * ChunkSize);
	    idx -= (z * ChunkSize * ChunkSize);
	    int y = idx / ChunkSize;
	    int x = idx % ChunkSize;
	    return Vec3i(x, y, z);
	}	

	void RebuildVoxelChunk()
	{	
		chunk_Vertexes.clear();
		chunk_IDs.clear();
		faceCount = 0;
		visible = false;

		for (int idx = 0; idx < ChunkSize*ChunkSize*ChunkSize; idx++)
		{
			Vec3i Pos = to3D(idx);
			int x = Pos.x+Cx;
			int y = Pos.y+Cy;
			int z = Pos.z+Cz;

			u8 blockType = map.mapData.GetCellType(x, y, z);
			if (blockType == 0)
			continue;
			
			for (u8 i = 0; i < 6; i++)	
			{						
				if ( !Block::isOpaque(map.mapData.GetNeighbor( x, y, z, i)))
				{
					if ( Block::isWater(blockType) && Block::isWater(map.mapData.GetNeighbor( x, y, z, i)) )
					continue;


					u8 Light = map.mapData.GetNeighborLight( x, y, z, i);

					switch (i)
					{								
						case 0: AddTopFace(    x, y, z, blockType, Light); break;
						case 1: AddNorthFace(  x, y, z, blockType, Light); break;
						case 2: AddEastFace(   x, y, z, blockType, Light); break;
						case 3: AddSouthFace(  x, y, z, blockType, Light); break;
						case 4: AddWestFace(   x, y, z, blockType, Light); break;
						case 5: AddBottomFace( x, y, z, blockType, Light); break;
					}			
				}
			}					
		}
	}

	void AddTopFace( int x, int y, int z, int blockType, u8 lightLevel) 
	{		
		SColor light(255, 20+(lightLevel*14),20+(lightLevel*14),20+(lightLevel*14));
		if (blockType == Block::GrassyDirt)
		blockType = Block::GrassTop;
	 	chunk_Vertexes.push_back(Vertex(x,   y,  z+1,   ((tUnit * (blockType)) + tUnit), 1, light));	//(tUnit * texturePos.x + tUnit, tUnit * texturePos.y));
	 	chunk_Vertexes.push_back(Vertex(x+1, y,  z+1,   ((tUnit * (blockType)) + tUnit), 0, light));	//(tUnit * texturePos.x + tUnit, tUnit * texturePos.y + tUnit));
	 	chunk_Vertexes.push_back(Vertex(x+1, y,  z,     ( tUnit * (blockType)), 			0, light));	//(tUnit * texturePos.x, tUnit * texturePos.y + tUnit));
	 	chunk_Vertexes.push_back(Vertex(x,   y,  z,     ( tUnit * (blockType)), 			1, light));  	//(tUnit * texturePos.x, tUnit * texturePos.y)); 	
	 	AddTriangles();
		faceCount++;
	}
	void AddNorthFace( int x, int y, int z, int blockType, u8 lightLevel) 
	{	
		SColor light(255, 20+(lightLevel*14),20+(lightLevel*14),20+(lightLevel*14));
	 	chunk_Vertexes.push_back(Vertex(x+1, y-1, z+1,   ((tUnit * blockType) + tUnit), 	1, light));	//(tUnit * texturePos.x + tUnit, tUnit * texturePos.y));
	 	chunk_Vertexes.push_back(Vertex(x+1, y,   z+1,   ((tUnit * blockType) + tUnit), 	0, light));							//(tUnit * texturePos.x + tUnit, tUnit * texturePos.y + tUnit));
	 	chunk_Vertexes.push_back(Vertex(x,   y,   z+1,   (tUnit * blockType), 				0, light));							//(tUnit * texturePos.x, tUnit * texturePos.y + tUnit));
	 	chunk_Vertexes.push_back(Vertex(x,   y-1, z+1,   (tUnit * blockType), 				1, light));  	//(tUnit * texturePos.x, tUnit * texturePos.y)); 	
		AddTriangles();
		faceCount++;
	}
	void AddEastFace( int x, int y, int z, int blockType, u8 lightLevel) 
	{
		SColor light(255, 20+(lightLevel*14),20+(lightLevel*14),20+(lightLevel*14));
	 	chunk_Vertexes.push_back(Vertex(x+1, y-1, z,   ((tUnit * blockType) + tUnit), 	1, light));	//(tUnit * texturePos.x + tUnit, tUnit * texturePos.y));
	 	chunk_Vertexes.push_back(Vertex(x+1, y,   z,   ((tUnit * blockType) + tUnit), 	0, light));							//(tUnit * texturePos.x + tUnit, tUnit * texturePos.y + tUnit));
	 	chunk_Vertexes.push_back(Vertex(x+1, y,   z+1,  (tUnit * blockType), 			0, light));							//(tUnit * texturePos.x, tUnit * texturePos.y + tUnit));
	 	chunk_Vertexes.push_back(Vertex(x+1, y-1, z+1,  (tUnit * blockType), 			1, light));  	//(tUnit * texturePos.x, tUnit * texturePos.y));
		AddTriangles();
		faceCount++;
	}
	void AddSouthFace( int x, int y, int z, int blockType, u8 lightLevel) 
	{
		SColor light(255, 20+(lightLevel*14),20+(lightLevel*14),20+(lightLevel*14));
	 	chunk_Vertexes.push_back(Vertex(x,   y-1, z,   ((tUnit * blockType) + tUnit), 	1, light));	//(tUnit * texturePos.x + tUnit, tUnit * texturePos.y));
	 	chunk_Vertexes.push_back(Vertex(x,   y,   z,   ((tUnit * blockType) + tUnit), 	0, light));							//(tUnit * texturePos.x + tUnit, tUnit * texturePos.y + tUnit));
	 	chunk_Vertexes.push_back(Vertex(x+1, y,   z,    (tUnit * blockType), 			0, light));							//(tUnit * texturePos.x, tUnit * texturePos.y + tUnit));
	 	chunk_Vertexes.push_back(Vertex(x+1, y-1, z,    (tUnit * blockType), 			1, light));  	//(tUnit * texturePos.x, tUnit * texturePos.y)); 	
		AddTriangles();
		faceCount++;
	}
	void AddWestFace( int x, int y, int z, int blockType, u8 lightLevel) 
	{
		SColor light(255, 20+(lightLevel*14),20+(lightLevel*14),20+(lightLevel*14));
	 	chunk_Vertexes.push_back(Vertex(x, y-1, z+1,   ((tUnit * blockType) + tUnit), 	1, light));	//(tUnit * texturePos.x + tUnit, tUnit * texturePos.y));
	 	chunk_Vertexes.push_back(Vertex(x, y,   z+1,   ((tUnit * blockType) + tUnit), 	0, light));							//(tUnit * texturePos.x + tUnit, tUnit * texturePos.y + tUnit));
	 	chunk_Vertexes.push_back(Vertex(x, y,   z,     (tUnit * blockType), 			0, light));							//(tUnit * texturePos.x, tUnit * texturePos.y + tUnit));
	 	chunk_Vertexes.push_back(Vertex(x, y-1, z,     (tUnit * blockType), 			1, light));  	//(tUnit * texturePos.x, tUnit * texturePos.y)); 	
		AddTriangles();
		faceCount++;
	}
	void AddBottomFace( int x, int y, int z, int blockType, u8 lightLevel) 
	{
		SColor light(255, 20+(lightLevel*14),20+(lightLevel*14),20+(lightLevel*14));
	 	chunk_Vertexes.push_back(Vertex(x,   y-1, z,   ((tUnit * blockType) + tUnit), 	1, light));	//(tUnit * texturePos.x + tUnit, tUnit * texturePos.y));
	 	chunk_Vertexes.push_back(Vertex(x+1, y-1, z,   ((tUnit * blockType) + tUnit), 	0, light));	//(tUnit * texturePos.x + tUnit, tUnit * texturePos.y + tUnit));
	 	chunk_Vertexes.push_back(Vertex(x+1, y-1, z+1,  (tUnit * blockType), 			0, light));	//(tUnit * texturePos.x, tUnit * texturePos.y + tUnit));
	 	chunk_Vertexes.push_back(Vertex(x,   y-1, z+1,  (tUnit * blockType), 			1, light));  	//(tUnit * texturePos.x, tUnit * texturePos.y)); 	
		AddTriangles();
		faceCount++;
	}
	void AddTriangles()
	{
		chunk_IDs.push_back(faceCount*4);
		chunk_IDs.push_back(faceCount*4 + 1);
		chunk_IDs.push_back(faceCount*4 + 2);
		chunk_IDs.push_back(faceCount*4);
		chunk_IDs.push_back(faceCount*4 + 2);
		chunk_IDs.push_back(faceCount*4 + 3); 
	}

	void Render(Vec3f pos, float[] model)
	{	
		//if (visible)
		{				
			Matrix::SetTranslation(model, -pos.x, -pos.y, -pos.z);			
			Render::SetModelTransform(model);
			Render::RawTrianglesIndexed(tiltex_name, chunk_Vertexes, chunk_IDs);	

		}			
	}
};
