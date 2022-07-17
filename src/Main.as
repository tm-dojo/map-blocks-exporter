
class UploadHandle
{
    string mapUId;
    Json::Value jsonBlocksPayload;
}

vec3 getRealCoords(nat3 coords)
{

    int realX = 32 * coords.x + 16;
    int realY = 8 * coords.y - 60;
    int realZ = 32 * coords.z + 16;

    vec3 coord(realX, realY, realZ);

    return coord;
}

void ExtractBlocks()
{ 
    auto app = GetApp();
    
    if (@app == null) {
        UI::ShowNotification("app == null");
        return;
    }

    auto map = app.RootMap;
    if (@map == null) {
        UI::ShowNotification("app.RootMap == null");
        return;
    }

    Json::Value payload = Json::Object();

    // BLOCKS
    Json::Value nadeoBlocks = Json::Array();
    Json::Value freeModeBlocks = Json::Array();
    for (int i = 0; i < int(map.Blocks.Length); i++) {
        Json::Value blockPayload = Json::Object();

        auto block = map.Blocks[i];

        // Name
        blockPayload["name"] = Json::Value(block.BlockModel.Name);

        // Thanks to zayshaa for free block detection code: https://gist.github.com/ZayshaaCodes/d4223fe200208d68e5afb206bdd39367
        // seems to be consistently 0 when the block is placed in free mode, this could easily change...
        auto isFree = Dev::GetOffsetInt8(block, 0x50) == 0;

        if (isFree) {	
            auto pos = Dev::GetOffsetVec3(block, 0x6c);
            auto rot = Dev::GetOffsetVec3(block, 0x78);	

            // Position
            Json::Value posJson = Json::Array();
            posJson.Add(pos.x);
            posJson.Add(pos.y);
            posJson.Add(pos.z);
            blockPayload["pos"] = posJson;

            // Position
            Json::Value rotJson = Json::Array();
            rotJson.Add(rot.x);
            rotJson.Add(rot.y);
            rotJson.Add(rot.z);
            blockPayload["rot"] = rotJson;

            freeModeBlocks.Add(blockPayload);
        } else  {
            // Direction
            blockPayload["dir"] = Json::Value(block.Direction);

            // Position
            Json::Value coordJson = Json::Array();
            vec3 coord = getRealCoords(block.Coord);
            coordJson.Add(coord.x);
            coordJson.Add(coord.y);
            coordJson.Add(coord.z);
            blockPayload["pos"] = coordJson;

            // BlockUnits
            Json::Value blockOffsetsJson = Json::Array();
            for (int j = 0; j < int(block.BlockUnits.Length); j++) {
                auto unit = block.BlockUnits[j];
                Json::Value offsetJson = Json::Array();
                offsetJson.Add(unit.Offset.x);
                offsetJson.Add(unit.Offset.y);
                offsetJson.Add(unit.Offset.z);
                blockOffsetsJson.Add(offsetJson);
            }
            blockPayload["blockOffsets"] = blockOffsetsJson;     

            nadeoBlocks.Add(blockPayload);        
        }

    }
    payload["nadeoBlocks"] = nadeoBlocks;
    payload["freeModeBlocks"] = freeModeBlocks;

    // ANCHORED OBJECTS
    Json::Value anchoredObjects = Json::Array();
    for (int i = 0; i < int(map.AnchoredObjects.Length); i++) {
        Json::Value anchoredObjectsPayload = Json::Object();

        {
            auto anchoredObject = map.AnchoredObjects[i];

            // Name
            auto blockId = anchoredObject.ItemModel.IdName;
            auto split = blockId.Split("\\");
            auto last = split[split.Length - 1];
            auto blockNameFromId = last.Replace(".Item.gbx", "").Replace(".Item.Gbx", "");
            anchoredObjectsPayload["name"] = Json::Value(blockNameFromId);

            // Position
            Json::Value coordJson = Json::Array();
            vec3 coord = anchoredObject.AbsolutePositionInMap;
            coordJson.Add(coord.x);
            coordJson.Add(coord.y);
            coordJson.Add(coord.z);
            anchoredObjectsPayload["pos"] = coordJson;

            // Pitch, Yaw, Roll
            anchoredObjectsPayload["pitch"] = Json::Value(anchoredObject.Pitch);
            anchoredObjectsPayload["yaw"] = Json::Value(anchoredObject.Yaw);
            anchoredObjectsPayload["roll"] = Json::Value(anchoredObject.Roll);
        }

        anchoredObjects.Add(anchoredObjectsPayload);
    }
    payload["anchoredObjects"] = anchoredObjects;
    

    // Send payload
    ref @uploadHandle = UploadHandle();
    cast<UploadHandle>(uploadHandle).mapUId = app.PlaygroundScript.Map.EdChallengeId;
    cast<UploadHandle>(uploadHandle).jsonBlocksPayload = payload;
    startnew(UploadMapData, uploadHandle);
}

void UploadMapData(ref @uploadHandle)
{
    print("Starting Upload");
    UploadHandle @uh = cast<UploadHandle>(uploadHandle);

    print(Json::Write(uh.jsonBlocksPayload));

    Net::HttpRequest req;
    req.Method = Net::HttpMethod::Post;
    req.Url = "http://localhost/map-blocks?mapUId=" + uh.mapUId;
    req.Body = Json::Write(uh.jsonBlocksPayload);
    dictionary@ Headers = dictionary();
    Headers["Content-Type"] = "application/json";
    @req.Headers = Headers;
    
    req.Start();

    while (!req.Finished()) {
        yield();
    }

    print("Finished Upload");
}

void RenderMenu()
{
	auto app = cast<CGameManiaPlanet>(GetApp());
	auto menus = cast<CTrackManiaMenus>(app.MenuManager);

	if (UI::BeginMenu("Map Block Extractor")) {
		if (UI::MenuItem("Extract Blocks (JSON)", "", false, true)) {
            startnew(ExtractBlocks);
		}
		UI::EndMenu();
	}
}
