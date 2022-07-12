
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
        UI::ShowNotification("map == null");
        return;
    }

    Json::Value payload = Json::Object();

    Json::Value nadeoBlocks = Json::Array();
    for (int i = 0; i < int(map.Blocks.Length); i++) {
        Json::Value blockPayload = Json::Object();

        {
            auto block = map.Blocks[i];

            // Name
            blockPayload["name"] = Json::Value(block.BlockModel.Name);

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
        }

        nadeoBlocks.Add(blockPayload);
    }

    payload["nadeoBlocks"] = nadeoBlocks;


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

	if (UI::BeginMenu("Block Extractor (JSON)")) {
		if (UI::MenuItem("Extract Blocks", "", false, true)) {
            ExtractBlocks();
		}
		UI::EndMenu();
	}
}

void Main()
{
    print("BlockExtractorJSON: Init");
}
