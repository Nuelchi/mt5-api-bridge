#!/usr/bin/env python3
"""
MT5 MQL5 Compiler for Docker Environment
Adapted from mt5compile for use with Docker MT5 container
"""

import os
import subprocess
import time
import re
import shutil
from pathlib import Path
from typing import Dict, Tuple, Optional
import logging

logger = logging.getLogger(__name__)


class MQLCompiler:
    """MQL5/MQL4 compiler for Docker MT5 environment"""
    
    def __init__(self):
        # Docker environment paths
        self.docker_container = "mt5"
        self.mt5_terminal_path = "/wine/drive_c/Program Files/MetaTrader 5"
        self.metaeditor_exe = "MetaEditor64.exe"
        self.experts_path = f"{self.mt5_terminal_path}/MQL5/Experts"
        self.compile_temp_dir = "/tmp/mql_compile"
        
        # Resolve docker binary location (systemd PATH might not include /usr/bin)
        self.docker_bin = (
            os.getenv("DOCKER_BIN")
            or shutil.which("docker")
            or "/usr/bin/docker"
        )
        
        if not shutil.which(self.docker_bin) and not os.path.exists(self.docker_bin):
            logger.warning(
                f"Docker binary not found at {self.docker_bin}. "
                "Set DOCKER_BIN env var if docker is installed elsewhere."
            )
        
        # Ensure temp directory exists
        os.makedirs(self.compile_temp_dir, exist_ok=True)
    
    def validate_mql_code(self, code: str) -> Tuple[bool, str]:
        """
        Basic validation of MQL5 code
        Returns: (is_valid, error_message)
        """
        # Check for required elements
        if "#property" not in code:
            return False, "Missing #property declarations"
        
        # Check for basic structure
        if "OnInit()" not in code and "OnTick()" not in code and "OnCalculate()" not in code:
            return False, "Missing required functions (OnInit/OnTick/OnCalculate)"
        
        # Check for common syntax errors
        if code.count("{") != code.count("}"):
            return False, "Mismatched curly braces"
        
        if code.count("(") != code.count(")"):
            return False, "Mismatched parentheses"
        
        return True, ""
    
    def sanitize_filename(self, filename: str) -> str:
        """Sanitize filename to prevent security issues"""
        # Remove directory traversal attempts
        filename = os.path.basename(filename)
        # Remove special characters except alphanumeric, underscore, hyphen, dot
        filename = re.sub(r'[^a-zA-Z0-9_\-\.]', '_', filename)
        return filename
    
    def compile_mql(
        self,
        code: str,
        filename: str,
        user_id: str,
        validate_only: bool = False
    ) -> Tuple[bool, Dict]:
        """
        Compile MQL5/MQL4 code
        
        Args:
            code: MQL source code
            filename: Desired filename (e.g., "MyEA.mq5")
            user_id: User ID for tracking
            validate_only: If True, only validate syntax without full compilation
        
        Returns:
            (success, result_dict)
            result_dict contains: compiled_path, errors, warnings, log
        """
        start_time = time.time()
        
        # Sanitize filename
        filename = self.sanitize_filename(filename)
        if not filename.endswith(('.mq5', '.mq4')):
            return False, {"error": "Filename must end with .mq5 or .mq4"}
        
        # Validate code
        is_valid, error_msg = self.validate_mql_code(code)
        if not is_valid:
            return False, {"error": f"Code validation failed: {error_msg}"}
        
        # Create source file in temp directory
        source_file = os.path.join(self.compile_temp_dir, filename)
        try:
            with open(source_file, 'w', encoding='utf-8') as f:
                f.write(code)
        except Exception as e:
            return False, {"error": f"Failed to write source file: {e}"}
        
        # Paths (host vs container)
        base_name = Path(filename).stem
        log_file = os.path.join(self.compile_temp_dir, f"{base_name}.log")
        container_source_dir = "/tmp/mql_compile"
        container_source_path = f"{container_source_dir}/{filename}"
        container_log_path = f"{container_source_dir}/{base_name}.log"
        
        # Ensure directory exists inside container and copy source file over
        try:
            subprocess.run(
                [self.docker_bin, "exec", self.docker_container,
                 "mkdir", "-p", container_source_dir],
                check=True,
                capture_output=True
            )
            
            subprocess.run(
                [self.docker_bin, "cp", source_file,
                 f"{self.docker_container}:{container_source_path}"],
                check=True,
                capture_output=True
            )
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to copy source into container: {e}")
            return False, {"error": f"Failed to prepare container for compilation: {e}"}
        
        # Build Docker exec command to compile inside container
        # MetaEditor will read/write from /tmp/mql_compile
        compile_cmd = [
            self.docker_bin, "exec", self.docker_container,
            "wine", f"{self.mt5_terminal_path}/{self.metaeditor_exe}",
            f'/compile:"{container_source_path}"',
            f'/log:"{container_log_path}"'
        ]
        
        if validate_only:
            compile_cmd.append('/s')  # Syntax check only
        
        logger.info(f"Compiling {filename} for user {user_id}")
        
        try:
            # Execute compilation
            result = subprocess.run(
                compile_cmd,
                capture_output=True,
                text=True,
                timeout=60
            )
            
            compile_time = time.time() - start_time
            
            # Copy log file back from container (if it exists)
            try:
                subprocess.run(
                    [self.docker_bin, "cp",
                     f"{self.docker_container}:{container_log_path}",
                     log_file],
                    check=True,
                    capture_output=True
                )
            except subprocess.CalledProcessError:
                logger.warning("Could not copy compilation log from container")
            
            # Read log file
            log_content = ""
            if os.path.exists(log_file):
                try:
                    with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                        log_content = f.read()
                except Exception as e:
                    logger.warning(f"Could not read log file: {e}")
            
            # Parse compilation results
            success, errors, warnings = self.parse_compilation_log(log_content)
            
            # Find compiled file
            compiled_path = None
            if success and not validate_only:
                if filename.endswith('.mq5'):
                    container_compiled_path = f"{container_source_dir}/{base_name}.ex5"
                    compiled_file = source_file.replace('.mq5', '.ex5')
                else:
                    container_compiled_path = f"{container_source_dir}/{base_name}.ex4"
                    compiled_file = source_file.replace('.mq4', '.ex4')
                
                try:
                    subprocess.run(
                        [self.docker_bin, "cp",
                         f"{self.docker_container}:{container_compiled_path}",
                         compiled_file],
                        check=True,
                        capture_output=True
                    )
                except subprocess.CalledProcessError as e:
                    logger.warning(f"Could not copy compiled file: {e}")
                    compiled_file = None
                
                if compiled_file and os.path.exists(compiled_file):
                    compiled_path = compiled_file
            
            result_dict = {
                "success": success,
                "filename": filename,
                "compiled_path": compiled_path,
                "errors": errors,
                "warnings": warnings,
                "compile_time": round(compile_time, 2),
                "log": log_content[:1000] if log_content else ""  # Truncate log
            }
            
            logger.info(f"Compilation {'successful' if success else 'failed'} "
                       f"for {filename} in {compile_time:.2f}s")
            
            return success, result_dict
            
        except subprocess.TimeoutExpired:
            return False, {"error": "Compilation timeout (60s exceeded)"}
        except Exception as e:
            logger.error(f"Compilation error: {e}")
            return False, {"error": f"Compilation error: {str(e)}"}
    
    def parse_compilation_log(self, log_content: str) -> Tuple[bool, list, list]:
        """
        Parse compilation log to extract results
        Returns: (success, errors_list, warnings_list)
        """
        if not log_content:
            return False, ["No compilation log available"], []
        
        errors = []
        warnings = []
        
        # Look for result line
        result_pattern = r"Result:\s*(\d+)\s*errors?,\s*(\d+)\s*warnings?"
        match = re.search(result_pattern, log_content, re.IGNORECASE)
        
        if match:
            error_count = int(match.group(1))
            warning_count = int(match.group(2))
            
            # Extract error details
            error_patterns = [
                r"(.+?)\s*:\s*error\s*(\d+):\s*(.+)",
                r"(.+?)\((\d+),(\d+)\)\s*:\s*error\s*(\d+):\s*(.+)"
            ]
            
            for line in log_content.split('\n'):
                for pattern in error_patterns:
                    match = re.search(pattern, line, re.IGNORECASE)
                    if match:
                        errors.append(line.strip())
                        break
                
                if 'warning' in line.lower():
                    warnings.append(line.strip())
            
            success = (error_count == 0)
            return success, errors[:10], warnings[:10]  # Limit to 10 each
        
        # Fallback: check for "code generated"
        if "code generated" in log_content.lower():
            return True, [], []
        
        return False, ["Compilation failed - check log for details"], []
    
    def deploy_to_mt5(
        self,
        compiled_file: str,
        ea_name: str,
        user_id: str
    ) -> Tuple[bool, str]:
        """
        Deploy compiled EA to MT5 Experts directory
        
        Args:
            compiled_file: Path to compiled .ex5/.ex4 file
            ea_name: Name for the EA
            user_id: User ID for tracking
        
        Returns:
            (success, message)
        """
        if not os.path.exists(compiled_file):
            return False, f"Compiled file not found: {compiled_file}"
        
        # Sanitize EA name
        ea_name = self.sanitize_filename(ea_name)
        
        # Determine destination in MT5 Experts folder
        # Create user-specific subfolder
        user_folder = f"Trainflow_{user_id[:8]}"
        dest_dir = f"{self.experts_path}/{user_folder}"
        
        # Copy file to MT5 via Docker
        dest_file = f"{dest_dir}/{os.path.basename(compiled_file)}"
        
        try:
            # Create user folder in Docker
            subprocess.run(
                [self.docker_bin, "exec", self.docker_container, 
                 "mkdir", "-p", dest_dir],
                check=True,
                capture_output=True
            )
            
            # Copy file into Docker container
            subprocess.run(
                [self.docker_bin, "cp", compiled_file, 
                 f"{self.docker_container}:{dest_file}"],
                check=True,
                capture_output=True
            )
            
            logger.info(f"Deployed {ea_name} to {dest_file} for user {user_id}")
            return True, f"EA deployed successfully to {user_folder}/{os.path.basename(compiled_file)}"
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Deployment failed: {e}")
            return False, f"Deployment failed: {e}"
    
    def cleanup_temp_files(self, filename: str):
        """Clean up temporary compilation files"""
        try:
            base_name = Path(filename).stem
            patterns = [
                f"{self.compile_temp_dir}/{filename}",
                f"{self.compile_temp_dir}/{base_name}.log",
                f"{self.compile_temp_dir}/{base_name}.ex5",
                f"{self.compile_temp_dir}/{base_name}.ex4",
            ]
            
            for pattern in patterns:
                if os.path.exists(pattern):
                    os.remove(pattern)
        except Exception as e:
            logger.warning(f"Cleanup error: {e}")


# Global compiler instance
compiler = MQLCompiler()


