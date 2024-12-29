import os
import sys
import ast
import time
import base64
import logging
import autogen
from typing_extensions import Annotated
from PIL import ImageGrab

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Configuration following official docs
config_list = [{
    "model": "gpt-4o-mini",
    "api_key": os.getenv("OPENAI_API_KEY")
}]

# Verify API key
if not os.getenv("OPENAI_API_KEY"):
    raise ValueError("OPENAI_API_KEY environment variable is not set")

# Configure OpenAI with retries
llm_config = {
    "config_list": config_list,
    "temperature": 0,
    "timeout": 120,
    "cache_seed": 42,
    "max_retries": 3,
    "functions": [
        {
            "name": "see_file",
            "description": "View file contents",
            "parameters": {
                "type": "object",
                "properties": {
                    "filename": {
                        "type": "string",
                        "description": "File path to read"
                    }
                },
                "required": ["filename"]
            }
        },
        {
            "name": "modify_code",
            "description": "Modify code safely",
            "parameters": {
                "type": "object",
                "properties": {
                    "filename": {
                        "type": "string",
                        "description": "Target file to modify"
                    },
                    "start_line": {
                        "type": "integer",
                        "description": "Start line number (1-indexed)"
                    },
                    "end_line": {
                        "type": "integer",
                        "description": "End line number (1-indexed)"
                    },
                    "new_code": {
                        "type": "string",
                        "description": "New code to insert"
                    }
                },
                "required": ["filename", "start_line", "end_line", "new_code"]
            }
        },
        {
            "name": "run_and_capture",
            "description": "Run app and analyze UI",
            "parameters": {
                "type": "object",
                "properties": {
                    "filename": {
                        "type": "string",
                        "description": "File to run"
                    }
                },
                "required": ["filename"]
            }
        }
    ]
}

# Configure the agents
engineer = autogen.AssistantAgent(
    name="Engineer",
    system_message="""Expert Python developer focused on debugging and improving Python applications.

CAPABILITIES:
1. Code analysis and debugging
2. UI/UX improvements
3. Best practices implementation
4. Continuous validation

WORKFLOW:
1. When asked to check code:
   - Use see_file to view contents
   - Analyze for issues
   - Report findings clearly

2. When fixing issues:
   - Explain the problem
   - Propose specific fix
   - Use modify_code to apply changes
   - Test and verify
   - Document changes

3. When improving UI:
   - Use run_and_capture to test
   - Analyze screenshot
   - Suggest improvements
   - Implement changes
   - Verify results

4. Always validate changes before moving on

Remember to use the provided tools:
- see_file: View file contents
- modify_code: Make changes
- run_and_capture: Test UI
- list_dir: Check files""",
    llm_config=llm_config
)

user_proxy = autogen.UserProxyAgent(
    name="Admin",
    system_message="""A user needing help with code improvements.
    
Role: Coordinate with the Engineer to improve the code.
- Initiate the debugging process
- Provide clear requirements
- Monitor progress
- Verify improvements""",
    human_input_mode="NEVER",
    code_execution_config={"use_docker": False}
)

# Core functions following docs pattern
@user_proxy.register_for_execution()
@engineer.register_for_llm(description="List directory contents")
def list_dir(directory: Annotated[str, "Directory path"]) -> tuple:
    try:
        logging.info(f"Listing directory: {directory}")
        files = os.listdir(directory)
        return 0, files
    except Exception as e:
        logging.error(f"Error listing directory: {str(e)}")
        return 1, str(e)

@user_proxy.register_for_execution()
@engineer.register_for_llm(description="View file contents")
def see_file(filename: Annotated[str, "File path"]) -> tuple:
    try:
        logging.info(f"Reading file: {filename}")
        with open(filename, "r") as file:
            lines = file.readlines()
        formatted_lines = [f"{i+1}:{line}" for i, line in enumerate(lines)]
        return 0, "".join(formatted_lines)
    except Exception as e:
        logging.error(f"Error reading file: {str(e)}")
        return 1, str(e)

@user_proxy.register_for_execution()
@engineer.register_for_llm(description="Run app and analyze UI")
def run_and_capture(filename: Annotated[str, "File to run"]) -> tuple:
    try:
        logging.info(f"Running and capturing UI: {filename}")
        # Run in background
        os.system(f"python {filename} &")
        time.sleep(5)  # Wait for startup
        
        # Capture UI and convert directly to base64
        screenshot = ImageGrab.grab()
        import io
        img_buffer = io.BytesIO()
        screenshot.save(img_buffer, format='PNG')
        img_base64 = base64.b64encode(img_buffer.getvalue()).decode()
        
        return 0, {
            "status": "Running",
            "image_data": {
                "type": "image",
                "data": img_base64,
                "format": "base64"
            }
        }
    except Exception as e:
        logging.error(f"Error capturing UI: {str(e)}")
        return 1, str(e)

@user_proxy.register_for_execution()
@engineer.register_for_llm(description="Modify code safely")
def modify_code(
    filename: Annotated[str, "Target file"],
    start_line: Annotated[int, "Start line"],
    end_line: Annotated[int, "End line"],
    new_code: Annotated[str, "New code"]
) -> tuple:
    try:
        logging.info(f"Modifying file: {filename} (lines {start_line}-{end_line})")
        # Backup
        backup = f"{filename}.bak"
        with open(filename, "r") as src, open(backup, "w") as dst:
            dst.write(src.read())
        
        # Modify
        with open(filename, "r") as file:
            lines = file.readlines()
        
        if not (0 < start_line <= len(lines) and 0 < end_line <= len(lines)):
            return 1, "Invalid line range"
        
        lines[start_line - 1 : end_line] = [new_code + "\n"]
        
        # Validate
        try:
            ast.parse("".join(lines))
        except SyntaxError as e:
            # Restore backup
            with open(backup, "r") as src, open(filename, "w") as dst:
                dst.write(src.read())
            logging.error(f"Syntax error in changes: {str(e)}")
            return 1, f"Syntax error: {str(e)}"
        
        # Save
        with open(filename, "w") as file:
            file.write("".join(lines))
        
        logging.info("Code modified successfully")
        return 0, "Modified successfully"
    except Exception as e:
        logging.error(f"Error modifying code: {str(e)}")
        return 1, str(e)

@user_proxy.register_for_execution()
@engineer.register_for_llm(description="Create new file")
def create_file_with_code(
    filename: Annotated[str, "Target file"],
    code: Annotated[str, "File content"]
) -> tuple:
    try:
        logging.info(f"Creating file: {filename}")
        with open(filename, "w") as file:
            file.write(code)
        return 0, "Created successfully"
    except Exception as e:
        logging.error(f"Error creating file: {str(e)}")
        return 1, str(e)

def main():
    try:
        if len(sys.argv) < 3:
            print("Usage: python autogen-autodebug-flow.py <file> <task>")
            sys.exit(1)
        
        target_file = sys.argv[1]
        task_prompt = sys.argv[2]
        
        if not os.path.exists(target_file):
            print(f"Error: {target_file} not found")
            sys.exit(1)

        logging.info(f"Starting AutoGen flow for {target_file}")
        logging.info(f"Task: {task_prompt}")

        # Create task-specific message
        task_msg = f"""Let's improve {target_file}. The goal is to debug and enhance the UI until it's perfect.

CURRENT TASK: {task_prompt}

REQUIRED STEPS:
1. First, use 'see_file' to check the current code:
   - Look for missing methods
   - Check for invalid props
   - Identify UI/UX issues
   - Review error handling

2. After analyzing the code, use 'run_and_capture' to test the UI:
   - Run the application
   - Capture the UI state
   - Analyze any visual issues

3. For each issue found:
   - Explain what's wrong
   - Propose a specific fix
   - Use 'modify_code' to implement the fix
   - Test the changes
   - Document what was changed

4. Repeat until everything is perfect:
   - No missing methods
   - All props are valid
   - UI looks and works great
   - Error handling is solid

Start by checking the code with 'see_file {target_file}'."""

        # Start direct chat between agents
        user_proxy.initiate_chat(
            engineer,
            message=task_msg
        )
    except Exception as e:
        logging.error(f"Error in main: {str(e)}")
        raise

if __name__ == "__main__":
    main() 