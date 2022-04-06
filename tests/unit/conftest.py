import pytest
from mock import MagicMock, patch

MockGreengrassSdk = MagicMock()
IoTDataPlane = MagicMock()

modules = {
    "greengrasssdk": MockGreengrassSdk,
    "greengrasssdk.IoTDataPlane": IoTDataPlane
}
patcher = patch.dict("sys.modules", modules)
patcher.start()