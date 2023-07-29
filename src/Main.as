
class UploadHandle
{
    string mapUId;
    // Json::Value jsonBlocksPayload;
}

vec3 getRealCoords(nat3 coords)
{

    int realX = 32 * coords.x + 16;
    int realY = 8 * coords.y - 60;
    int realZ = 32 * coords.z + 16;

    vec3 coord(realX, realY, realZ);

    return coord;
}

Json::Value payload = Json::Object();
string payloadString = "";

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

    payload = Json::Object();

    // BLOCKS
    Json::Value nadeoBlocks = Json::Array();
    Json::Value freeModeBlocks = Json::Array();
    for (int i = 0; i < int(map.Blocks.Length); i++) {
    // for (int i = 0; i < int(72500); i++) {
        if (i % 1000 == 0) {
            print("Blocks: " + i + "/" + int(map.Blocks.Length));
            yield();
        }

        Json::Value blockPayload = Json::Object();

        auto block = map.Blocks[i];

        if (block.BlockModel.Name == "VoidBlock1x1") continue;
        if (block.BlockModel.Name == "VoidFull") continue;
        if (block.BlockModel.Name == "Grass") continue;

        print("i: " + i + " " + block.BlockModel.Name);

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

    print(nadeoBlocks.Length);
    print(freeModeBlocks.Length);

    payload["nadeoBlocks"] = nadeoBlocks;
    payload["freeModeBlocks"] = freeModeBlocks;

    // ANCHORED OBJECTS
    Json::Value anchoredObjects = Json::Array();
    for (int i = 0; i < int(map.AnchoredObjects.Length); i++) {
        if (i % 1000 == 0) {
            print("Anchored objects: " + i + "/" + int(map.AnchoredObjects.Length));
            yield();
        }

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
    print(anchoredObjects.Length);

    print("Set anchored objects");

    yield();

    payloadString = Json::Write(payload);
    print("Write payloadString");

    yield();
    
    IO::SetClipboard(payloadString);
    // // Send payload
    // ref @uploadHandle = UploadHandle();
    // print("Init uploadHandle");
    // cast<UploadHandle>(uploadHandle).mapUId = app.PlaygroundScript.Map.EdChallengeId;
    // // print("Set map ID");
    // // cast<UploadHandle>(uploadHandle).jsonBlocksPayload = payload;
    // print("Set payload");
    // startnew(UploadMapData, uploadHandle);

}

void UploadMapData(ref @uploadHandle)
{
    print("Starting Upload");
    UploadHandle @uh = cast<UploadHandle>(uploadHandle);

    // print(Json::Write(uh.payload));

    Net::HttpRequest req;
    req.Method = Net::HttpMethod::Post;
    req.Url = "http://localhost/map-blocks?mapUId=" + uh.mapUId;
    req.Body = payloadString;
    dictionary@ Headers = dictionary();
    Headers["Content-Type"] = "application/json";
    @req.Headers = Headers;
    
    req.Start();

    print("Request started");

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
