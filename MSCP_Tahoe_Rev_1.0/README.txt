The macOS Security Compliance Project is an open source to provide a programmatic approach to generating security guidance. The configuration settings in this document were derived from National Institute of Standards and Technology (NIST) Special Publication (SP) 800-53, Security and Privacy Controls for Information Systems and Organizations, Revision 5. This is a joint project of federal operational IT Security staff from the National Institute of Standards and Technology (NIST), National Aeronautics and Space Administration (NASA), Defense Information Systems Agency (DISA), and Los Alamos National Laboratory (LANL).

    To learn more about the project, please see the GitHub project page https://github.com/usnistgov/macos_security.
    
# Changelog

This document provides a high-level view of the changes to the macOS Security Compliance Project.

## [Tahoe, Revision 1.0] - 2025-09-11

* Rules
  * Added Rules
    * os_loginwindow_adminhostinfo_disabled
    * os_safari_clear_history_disable
    * os_safari_private_browsing_disable
    * os_skip_apple_intelligence_enable
    * system_settings_download_software_update_enforce
    * system_settings_security_update_install
  * Modified Rules
    * audit_auditd_enabled
    * os_appleid_prompt_disable
    * os_authenticated_root_enable
    * os_external_storage_access_defined
    * os_httpd_disable
    * os_icloud_storage_prompt_disable
    * os_network_storage_restriction
    * os_privacy_setup_prompt_disable
    * os_recovery_lock_enable
    * os_screensaver_loginwindow_enforce
    * os_secure_boot_verify
    * os_siri_prompt_disable
    * os_skip_screen_time_prompt_enable
    * os_skip_unlock_with_watch_enable
    * os_tftpd_disable
    * os_time_server_enabled
    * os_touchid_prompt_disable
    * os_unlock_active_user_session_disable
    * os_world_writable_library_folder_configure
    * os_uucp_disable
    * pwpolicy_account_lockout_enforce
    * pwpolicy_account_lockout_timeout_enforce
    * pwpolicy_history_enforce
    * pwpolicy_lower_case_character_enforce
    * pwpolicy_max_lifetime_enforce
    * pwpolicy_minimum_length_enforce
    * pwpolicy_minimum_lifetime_enforce
    * pwpolicy_special_character_enforce
    * pwpolicy_upper_case_character_enforce
    * system_settings_bluetooth_sharing_disable
    * system_settings_hot_corners_secure
    * system_settings_location_services_disable
    * system_settings_location_services_enable
    * system_settings_screen_sharing_disable
    * system_settings_ssh_disable
    * system_settings_time_machine_encrypted_configure
  * Removed Rules
    * os_loginwindow_adminhostinfo_undefined
    * os_show_filename_extensions_enable
    * system_settings_security_update_install
    * system_settings_software_update_enforce
  * Bug Fixes
* Baselines
  * Modified existing baselines
* Scripts
  * generate_guidance
    * Added flag for consolidated configuration profile
    * Updated DDM logic for nested keys
    * Added shell check to compliance script
    * Updated current user check in compliance script
    * Support for Managed Arguments in compliance script
    * Bug Fixes
  * generate_scap
    * Support for oval 5.12.1
    * Support for scap 1.4
    * Added shellcommand for all tests

    DISCLAIMER
    ----------
    THE SOFTWARE IS PROVIDED "AS IS" WITHOUT ANY WARRANTY OF ANY KIND, EITHER EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, ANY WARRANTY THAT THE SOFTWARE WILL CONFORM TO SPECIFICATIONS, ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND FREEDOM FROM INFRINGEMENT, AND ANY WARRANTY THAT THE DOCUMENTATION WILL CONFORM TO THE SOFTWARE, OR ANY WARRANTY THAT THE SOFTWARE WILL BE ERROR FREE.  IN NO EVENT SHALL NIST BE LIABLE FOR ANY DAMAGES, INCLUDING, BUT NOT LIMITED TO, DIRECT, INDIRECT, SPECIAL OR CONSEQUENTIAL DAMAGES, ARISING OUT OF, RESULTING FROM, OR IN ANY WAY CONNECTED WITH THIS SOFTWARE, WHETHER OR NOT BASED UPON WARRANTY, CONTRACT, TORT, OR OTHERWISE, WHETHER OR NOT INJURY WAS SUSTAINED BY PERSONS OR PROPERTY OR OTHERWISE, AND WHETHER OR NOT LOSS WAS SUSTAINED FROM, OR AROSE OUT OF THE RESULTS OF, OR USE OF, THE SOFTWARE OR SERVICES PROVIDED HEREUNDER.
