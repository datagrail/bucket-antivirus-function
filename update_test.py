# -*- coding: utf-8 -*-
# Upside Travel, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import unittest

import mock

import update


@mock.patch("update.boto3")
@mock.patch("update.clamav")
class TestUpdate(unittest.TestCase):
    def setUp(self):
        self.addCleanup(mock.patch.stopall)
        mock.patch("update.os.path.exists", return_value=False).start()

    def test_freshclam_success_does_not_raise(self, mock_clamav, _mock_boto3):
        mock_clamav.update_defs_from_s3.return_value = {}
        mock_clamav.update_defs_from_freshclam.return_value = 0

        update.lambda_handler({}, None)

        mock_clamav.upload_defs_to_s3.assert_called_once()

    def test_freshclam_failure_uploads_then_raises(self, mock_clamav, _mock_boto3):
        mock_clamav.update_defs_from_s3.return_value = {}
        mock_clamav.update_defs_from_freshclam.return_value = 2

        with self.assertRaises(RuntimeError):
            update.lambda_handler({}, None)

        mock_clamav.upload_defs_to_s3.assert_called_once()
