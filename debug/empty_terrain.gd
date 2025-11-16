extends Terrain

func _add_starting_chunks():
	add_chunk(-1, -1, ChunkType.EMPTY)
	add_chunk(0, -1, ChunkType.EMPTY)
	add_chunk(1, -1, ChunkType.EMPTY)
	add_chunk(-1, 0, ChunkType.EMPTY)
	add_chunk(0, 0, ChunkType.EMPTY)
	add_chunk(1, 0, ChunkType.EMPTY)
	add_chunk(-1, 1, ChunkType.EMPTY)
	add_chunk(0, 1, ChunkType.EMPTY)
	add_chunk(1, 1, ChunkType.EMPTY)
