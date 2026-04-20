-- Compiled by Scene2Res, a MTA:SA GTA III engine map importer
local textureCache = {};
local streamedObjects = {};
local pModels = {};

setCloudsEnabled(false);
debug.sethook(nil);

local function getResourceSize(path)
	if not (fileExists(path)) then return 0; end;

	local file = fileOpen(path);
	local size = fileGetSize(file)

	fileClose(file);
	return size;
end

local function requestTexture(model, path)
	local txd = textureCache[path];

	if not (txd) then
		local size = getResourceSize(path);
		if (size == 0) then return false; end

		txd = engineLoadTXD(path, false);

		if not (txd) then
			return false;
		end

		textureCache[path] = txd;
	end
	return txd;
end

local function loadModel(model)
	if (model.loaded) then return true; end

	if (model.super) then
       local superModel = pModels[model.super];
       if (superModel) then
		    if not (loadModel(superModel)) then
			    return false;
		    end
       end
	end

	engineReplaceModel(model.model, model.id);
	engineReplaceCOL(model.col, model.id);

	model.loaded = true;
	return true;
end

local function freeModel(model)
	if not (model.loaded) then return true; end

	engineRestoreModel(model.id);
	engineRestoreCOL(model.id);

	model.loaded = false;
	if (model.super) then
       local superModel = pModels[model.super];
       if (superModel) then
		    freeModel(superModel);
       end
	end
end

local function modelStreamOut ()
	local pModel = pModels[getElementModel(source)];

	if not (pModel) then return end;

	if (pModel.lodID) then return true; end

	if (pModel.isRequesting == 2) then
		pModel.isRequesting = 1;
		return true;
	elseif (pModel.isRequesting == 3) then
		pModel.isRequesting = 4;
		return true;
	elseif (pModel.isRequesting) then return true; end

	pModel.numStream = pModel.numStream - 1;

	if (pModel.numStream == 0) then
		pModel.isRequesting = 3;

		freeModel(pModel);

		pModel.isRequesting = false;
	end
end

local function modelStreamIn ()
	local pModel = pModels[getElementModel(source)];

	if not (pModel) then return end;

	if (pModel.lodID) then return true; end

	if (pModel.isRequesting == 1) then
		pModel.isRequesting = false;
		return true;
	elseif (pModel.isRequesting) then return true; end

	pModel.numStream = pModel.numStream + 1;

	if not (pModel.numStream == 1) then return true; end

	pModel.isRequesting = 2;

	if not (loadModel(pModel)) then
		setElementInterior(source, 123);
		setElementCollisionsEnabled(source, false);
	end

	if (pModel.isRequesting == 2) then
		outputDebugString("invalid model request '"..pModel.name.."'");
		freeModel(pModel);
		pModel.isRequesting = false;

		pModel.numStream = 0;
	end
end

function loadModels ()
	local pModel, pTXD, pColl, pTable;

	pTable={

	};

	for m,n in ipairs(pTable) do
		pModels[n[1]] = {
			id = n[1],
			name = n[2],
			txd = requestTexture(false, "textures/"..n[3]..".txd"),
			numStream = 0,
			lod = n[4] / 5,
			super = n[5]
		};
		pModelEntry = pModels[n[1]];
		engineImportTXD(pModelEntry.txd, n[1]);
		pModelEntry.model = engineLoadDFF("models/"..n[2]..".dff", n[1]);
		engineReplaceModel(pModelEntry.model, n[1]);
		if ( #n == 6 ) then
			pModelEntry.col = engineLoadCOL("coll/"..n[6]..".col");
			engineReplaceCOL(pModelEntry.col, n[1]);
		end
		engineSetModelLODDistance(n[1], n[4] / 5);
	end

	pTable={
		{ model=11595, model_file="road_03", txd_file="1", coll_file="road_03", lod=10000 },
		{ model=11596, model_file="road_00", txd_file="1", coll_file="road_00", lod=10000 },
		{ model=11597, model_file="road_01", txd_file="1", coll_file="road_01", lod=10000 },
		{ model=11598, model_file="road_02", txd_file="1", coll_file="road_02", lod=10000 },
		{ model=11599, model_file="other_13", txd_file="1", coll_file="other_13", lod=10000 },
		{ model=11600, model_file="other_12", txd_file="1", coll_file="other_12", lod=10000 },
		{ model=11601, model_file="other_11", txd_file="1", coll_file="other_11", lod=10000 },
		{ model=11602, model_file="other_10", txd_file="1", coll_file="other_10", lod=10000 },
		{ model=11603, model_file="other_09", txd_file="1", coll_file="other_09", lod=10000 },
		{ model=11604, model_file="other_08", txd_file="1", coll_file="other_08", lod=10000 },
		{ model=11605, model_file="other_07", txd_file="1", coll_file="other_07", lod=10000 },
		{ model=11606, model_file="other_06", txd_file="1", coll_file="other_06", lod=10000 },
		{ model=11607, model_file="other_05", txd_file="1", coll_file="other_05", lod=10000 },
		{ model=11611, model_file="other_04", txd_file="1", coll_file="other_04", lod=10000 },
		{ model=11612, model_file="other_03", txd_file="1", coll_file="other_03", lod=10000 },
		{ model=11613, model_file="other_02", txd_file="1", coll_file="other_02", lod=10000 },
		{ model=11614, model_file="other_01", txd_file="1", coll_file="other_01", lod=10000 },
		{ model=11615, model_file="other_00", txd_file="1", coll_file="other_00", lod=10000 },
		{ model=11616, model_file="trava_05", txd_file="1", coll_file="trava_05", lod=10000 },
		{ model=11617, model_file="trava_04", txd_file="1", coll_file="trava_04", lod=10000 },
		{ model=11618, model_file="trava_03", txd_file="1", coll_file="trava_03", lod=10000 },
		{ model=11619, model_file="trava_02", txd_file="1", coll_file="trava_02", lod=10000 },
		{ model=11620, model_file="trava_01", txd_file="1", coll_file="trava_01", lod=10000 },
		{ model=11621, model_file="trava_00", txd_file="1", coll_file="trava_00", lod=10000 },
		{ model=11622, model_file="tree_11", txd_file="1", coll_file="tree_11", lod=10000 },
		{ model=11623, model_file="tree_10", txd_file="1", coll_file="tree_10", lod=10000 },
		{ model=11624, model_file="tree_09", txd_file="1", coll_file="tree_09", lod=10000 },
		{ model=11628, model_file="tree_08", txd_file="1", coll_file="tree_08", lod=10000 },
		{ model=11629, model_file="tree_07", txd_file="1", coll_file="tree_07", lod=10000 },
		{ model=11630, model_file="tree_06", txd_file="1", coll_file="tree_06", lod=10000 },
		{ model=11632, model_file="tree_05", txd_file="1", coll_file="tree_05", lod=10000 },
		{ model=11633, model_file="tree_04", txd_file="1", coll_file="tree_04", lod=10000 },
		{ model=11634, model_file="tree_03", txd_file="1", coll_file="tree_03", lod=10000 },
		{ model=11635, model_file="tree_02", txd_file="1", coll_file="tree_02", lod=10000 },
		{ model=11636, model_file="tree_01", txd_file="1", coll_file="tree_01", lod=10000 },
		{ model=11637, model_file="tree_00", txd_file="1", coll_file="tree_00", lod=10000 },
		{ model=11638, model_file="road_04", txd_file="1", coll_file="road_04", lod=10000 },
		{ model=11639, model_file="road_05", txd_file="1", coll_file="road_05", lod=10000 },
		{ model=11640, model_file="trava_06", txd_file="1", coll_file="trava_06", lod=10000 },
		{ model=11641, model_file="trava_07", txd_file="1", coll_file="trava_07", lod=10000 }
	};

	local n,m;

	for n,m in ipairs(pTable) do
		pModels[m.model] = {
			id = m.model,
			name = m.model_file,
			txd = requestTexture(false, "textures/"..m.txd_file..".txd"),
			numStream = 0,
			lod = m.lod,
			lodID = m.lodID
		};
		pModelEntry = pModels[m.model];
       if (pModelEntry.txd) then
		    engineImportTXD(pModelEntry.txd, m.model);
       end
		pModelEntry.model=engineLoadDFF("models/"..m.model_file..".dff", m.model);
		pModelEntry.col=engineLoadCOL("coll/"..m.coll_file..".col");
		engineSetModelLODDistance(m.model, m.lod);

		if (m.lodID) then
			for j,k in ipairs(getElementsByType("object", resourceRoot)) do
				if (getElementModel(k) == m.model) then
					local x, y, z = getElementPosition(k);
					local rx, ry, rz = getElementRotation(k);
					setLowLODElement(k, createObject(m.lodID, x, y, z, rx, ry, rz, true));
				end
			end
		end
	end

	for m,n in pairs(pModels) do
		if (n.super) and not (n.col) then
           local superModel = pModels[n.super];
           if (superModel) then
			    n.col = superModel.col;
           end
		end
	end
end
loadModels();

for m,n in ipairs(getElementsByType("object", resourceRoot)) do
	if (isElementStreamedIn(n)) then
		source = n;
		modelStreamIn();
	end
end

addEventHandler("onClientElementStreamIn", resourceRoot, function()
		modelStreamIn();
	end
);
addEventHandler("onClientElementStreamOut", resourceRoot, function()
		modelStreamOut();
	end
);

addEventHandler("onClientResourceStop", resourceRoot, function()
		for m,n in pairs(pModels) do
			if (isElement(n.col)) then destroyElement(n.col); end
			if (isElement(n.model)) then destroyElement(n.model); end
			engineRestoreCOL(m);
			engineRestoreModel(m);
		end
       for m,n in pairs(textureCache) do
           destroyElement(n);
       end
	end
);

collectgarbage("collect");
local objects = getElementsByType ( "object", resourceRoot ) 
for theKey,object in ipairs(objects) do 
local id = getElementModel(object) 
local x,y,z = getElementPosition(object) 
local rx,ry,rz = getElementRotation(object) 
local scale = getObjectScale(object) 
objLowLOD = createObject ( id, x,y,z,rx,ry,rz,true ) 
setObjectScale(objLowLOD, scale) 
setLowLODElement ( object, objLowLOD ) 
engineSetModelLODDistance ( id, 3000 ) 
setElementStreamable ( object , false) 
end