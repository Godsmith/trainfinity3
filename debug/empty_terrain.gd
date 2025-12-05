extends Terrain

func set_seed_and_add_starting_chunks(randomizer_seed: int):
	_add_chunk(-1, -1, ChunkType.EMPTY)
	_add_chunk(0, -1, ChunkType.EMPTY)
	_add_chunk(1, -1, ChunkType.EMPTY)
	_add_chunk(-1, 0, ChunkType.EMPTY)
	_add_chunk(0, 0, ChunkType.EMPTY)
	_add_chunk(1, 0, ChunkType.EMPTY)
	_add_chunk(-1, 1, ChunkType.EMPTY)
	_add_chunk(0, 1, ChunkType.EMPTY)
	_add_chunk(1, 1, ChunkType.EMPTY)
