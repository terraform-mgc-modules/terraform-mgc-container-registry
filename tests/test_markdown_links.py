import pytest
import unittest.mock as mock
from pathlib import Path
import tempfile
import os
import re
import shutil
from unittest.mock import patch, MagicMock
import requests
from dataclasses import dataclass
from typing import List, Optional, Set
from urllib.parse import urlparse, urljoin

@dataclass
class LinkValidationResult:
    """Result of markdown link validation."""
    valid_links: int = 0
    broken_links: int = 0
    all_links: List[str] = None
    errors: List[str] = None

    def __post_init__(self):
        if self.all_links is None:
            self.all_links = []
        if self.errors is None:
            self.errors = []

    @property
    def total_links(self) -> int:
        return self.valid_links + self.broken_links

    def add_valid_link(self, link: str):
        self.valid_links += 1
        self.all_links.append(link)

    def add_broken_link(self, link: str, error: str):
        self.broken_links += 1
        self.all_links.append(link)
        self.errors.append(f"{link}: {error}")

@dataclass
class ValidationConfig:
    """Configuration for markdown link validation."""
    ignore_external_links: bool = False
    ignore_anchor_links: bool = False
    timeout: int = 30
    max_retries: int = 3
    custom_patterns: List[str] = None

    def __post_init__(self):
        if self.custom_patterns is None:
            self.custom_patterns = []

def extract_links_from_content(content: str, custom_patterns: List[str] = None) -> List[str]:
    """Extract markdown links from content, ignoring code blocks and inline code."""
    # Remove fenced code blocks
    content = re.sub(r'```.*?```', '', content, flags=re.DOTALL)
    # Remove inline code
    content = re.sub(r'`[^`]*`', '', content)
    links: List[str] = []
    patterns = [
        r'\[([^\]]*)\]\(([^)]+)\)',   # [text](url)
        r'\[([^\]]*)\]\[([^\]]*)\]',  # [text][ref]
        r'^\[([^\]]*)\]:\s*(.+)$',    # [ref]: url
    ]
    if custom_patterns:
        patterns.extend(custom_patterns)
    for pattern in patterns:
        for match in re.findall(pattern, content, re.MULTILINE):
            if isinstance(match, tuple):
                link = match[1] if len(match) > 1 else match[0]
            else:
                link = match
            if link and link.strip():
                links.append(link.strip())
    return links

def is_internal_link(link: str) -> bool:
    """Check if a link is internal (relative path or anchor)."""
    return not link.startswith(('http://', 'https://', 'ftp://', 'mailto:'))

def is_external_link(link: str) -> bool:
    """Check if a link is external (HTTP/HTTPS)."""
    return link.startswith(('http://', 'https://'))

def validate_markdown_links(file_path: Path, config: ValidationConfig = None) -> LinkValidationResult:
    """Validate all links in a markdown file."""
    if config is None:
        config = ValidationConfig()
    if not file_path.exists():
        raise FileNotFoundError(f"File not found: {file_path}")
    if file_path.is_dir():
        raise IsADirectoryError(f"Path is a directory: {file_path}")
    if file_path.suffix.lower() not in ['.md', '.markdown']:
        raise ValueError("Not a markdown file")

    content = file_path.read_text(encoding='utf-8')
    links = extract_links_from_content(content, config.custom_patterns)
    result = LinkValidationResult()

    for link in links:
        if config.ignore_external_links and is_external_link(link):
            continue
        if config.ignore_anchor_links and link.startswith('#'):
            continue
        try:
            if is_internal_link(link):
                _validate_internal_link(file_path, link, result)
            else:
                _validate_external_link(link, result, config)
        except Exception as e:
            result.add_broken_link(link, str(e))
    return result

def _validate_internal_link(base_path: Path, link: str, result: LinkValidationResult):
    """Validate an internal link."""
    if link.startswith('#'):
        result.add_valid_link(link)
        return
    link_path = link.split('#')[0]
    if not link_path:
        result.add_valid_link(link)
        return
    target = (base_path.parent / link_path).resolve()
    if target.exists():
        result.add_valid_link(link)
    else:
        result.add_broken_link(link, "File not found")

def _validate_external_link(link: str, result: LinkValidationResult, config: ValidationConfig):
    """Validate an external link."""
    try:
        response = requests.head(link, timeout=config.timeout, allow_redirects=True)
        if response.status_code < 400:
            result.add_valid_link(link)
        else:
            result.add_broken_link(link, f"HTTP {response.status_code}")
    except requests.exceptions.RequestException as e:
        result.add_broken_link(link, str(e))

def validate_multiple_markdown_files(files: List[Path], config: ValidationConfig = None) -> List[LinkValidationResult]:
    """Validate links in multiple markdown files."""
    return [validate_markdown_links(f, config) for f in files]

class TestMarkdownLinks:
    """Comprehensive test suite for markdown link validation."""

    @pytest.fixture(autouse=True)
    def setup_method(self):
        """Set up test fixtures before each test method."""
        self.temp_dir = Path(tempfile.mkdtemp())
        self.test_md_file = self.temp_dir / "test.md"

    def teardown_method(self):
        """Clean up after each test method."""
        if hasattr(self, 'temp_dir') and self.temp_dir.exists():
            shutil.rmtree(self.temp_dir)

    def test_valid_internal_links(self):
        """Test validation of valid internal markdown links."""
        markdown_content = """
        # Test Document
        [Link to section](#section-1)
        [Link to file](./other.md)
        [Another link](../parent/file.md)
        [Same directory](file.md)
        """
        self.test_md_file.write_text(markdown_content)
        (self.temp_dir / "other.md").write_text("# Other file")
        (self.temp_dir / "file.md").write_text("# Same directory file")
        parent_dir = self.temp_dir.parent / "parent"
        parent_dir.mkdir(exist_ok=True)
        (parent_dir / "file.md").write_text("# Parent file")

        result = validate_markdown_links(self.test_md_file)
        assert result.valid_links == 4
        assert result.broken_links == 0

    def test_valid_external_links(self):
        """Test validation of valid external HTTP/HTTPS links."""
        markdown_content = """
        # External Links
        [GitHub](https://github.com)
        [Python](https://python.org)
        [Local HTTP](http://localhost:8000)
        """
        self.test_md_file.write_text(markdown_content)
        with mock.patch('requests.head') as mock_head:
            mock_head.return_value.status_code = 200
            result = validate_markdown_links(self.test_md_file)
            assert result.valid_links == 3
            assert result.broken_links == 0
            assert mock_head.call_count == 3

    def test_mixed_valid_links(self):
        """Test a mix of valid internal and external links."""
        markdown_content = """
        # Mixed Links
        [Internal](./internal.md)
        [External](https://example.com)
        [Anchor](#section)
        [Image](./image.png)
        """
        self.test_md_file.write_text(markdown_content)
        (self.temp_dir / "internal.md").write_text("# Internal")
        (self.temp_dir / "image.png").write_text("fake image")
        with mock.patch('requests.head') as mock_head:
            mock_head.return_value.status_code = 200
            result = validate_markdown_links(self.test_md_file)
            assert result.valid_links == 4
            assert result.broken_links == 0

    def test_edge_case_link_formats(self):
        """Test various edge cases in markdown link formats."""
        markdown_content = """
        # Edge Cases
        [Empty link]()
        [Space in link](file with spaces.md)
        [Special chars](file-with_special.chars.md)
        [Reference link][ref]
        [Implicit reference][]
        [URL with query](https://example.com?param=value&other=123)
        [URL with fragment](https://example.com#section)

        [ref]: https://example.com
        [Implicit reference]: ./implicit.md
        """
        self.test_md_file.write_text(markdown_content)
        (self.temp_dir / "file with spaces.md").write_text("# Spaces")
        (self.temp_dir / "file-with_special.chars.md").write_text("# Special")
        (self.temp_dir / "implicit.md").write_text("# Implicit")
        with mock.patch('requests.head') as mock_head:
            mock_head.return_value.status_code = 200
            result = validate_markdown_links(self.test_md_file)
            assert result.total_links >= 7

    def test_nested_and_complex_markdown(self):
        """Test links within complex markdown structures."""
        markdown_content = """
        # Complex Markdown

        | Column 1 | Column 2 |
        |----------|----------|
        | [Table link](./table.md) | [Another](./another.md) |

        > [Quote link](./quote.md)

        - [List item 1](./list1.md)
        - [List item 2](./list2.md)

        1. [Ordered list](./ordered.md)
        2. [Second item](./second.md)

        **[Bold link](./bold.md)**
        *[Italic link](./italic.md)*

        ```markdown
        [Code block link](./code.md)
        ```

        `[Inline code link](./inline.md)`
        """
        self.test_md_file.write_text(markdown_content)
        for filename in ["table.md", "another.md", "quote.md", "list1.md",
                         "list2.md", "ordered.md", "second.md", "bold.md", "italic.md"]:
            (self.temp_dir / filename).write_text(f"# {filename}")
        result = validate_markdown_links(self.test_md_file)
        assert result.valid_links == 9
        assert result.broken_links == 0

    def test_image_links(self):
        """Test image link validation."""
        markdown_content = """
        # Images
        ![Alt text](./image.png)
        ![Another image](./subfolder/image.jpg)
        ![External image](https://example.com/image.gif)
        [![Linked image](./thumb.png)](./full.png)
        """
        self.test_md_file.write_text(markdown_content)
        (self.temp_dir / "image.png").write_text("fake png")
        (self.temp_dir / "subfolder").mkdir()
        (self.temp_dir / "subfolder" / "image.jpg").write_text("fake jpg")
        (self.temp_dir / "thumb.png").write_text("fake thumb")
        (self.temp_dir / "full.png").write_text("fake full")
        with mock.patch('requests.head') as mock_head:
            mock_head.return_value.status_code = 200
            result = validate_markdown_links(self.test_md_file)
            assert result.valid_links == 5
            assert result.broken_links == 0

    def test_broken_internal_links(self):
        """Test detection of broken internal links."""
        markdown_content = """
        # Broken Links
        [Missing file](./nonexistent.md)
        [Bad path](../../../nonexistent/file.md)
        [Broken relative](./missing/file.md)
        [Empty path](./)
        """
        self.test_md_file.write_text(markdown_content)
        result = validate_markdown_links(self.test_md_file)
        assert result.broken_links >= 3
        assert result.valid_links <= 1
        assert len(result.errors) >= 3

    def test_broken_external_links(self):
        """Test detection of broken external links."""
        markdown_content = """
        # External Broken Links
        [404 Link](https://httpstat.us/404)
        [500 Link](https://httpstat.us/500)
        [Timeout Link](https://httpstat.us/408)
        [Bad URL](https://thisdoesnotexist.invalid)
        """
        self.test_md_file.write_text(markdown_content)
        with mock.patch('requests.head') as mock_head:
            mock_head.side_effect = [
                mock.Mock(status_code=404),
                mock.Mock(status_code=500),
                mock.Mock(status_code=408),
                requests.exceptions.ConnectionError("Name resolution failed")
            ]
            result = validate_markdown_links(self.test_md_file)
            assert result.broken_links == 4
            assert result.valid_links == 0
            assert "404" in str(result.errors[0])
            assert "500" in str(result.errors[1])

    def test_network_errors(self):
        """Test handling of network errors."""
        markdown_content = """
        [Timeout](https://example.com/timeout)
        [Connection Error](https://example.com/connection)
        [DNS Error](https://nonexistent.invalid)
        """
        self.test_md_file.write_text(markdown_content)
        with mock.patch('requests.head') as mock_head:
            mock_head.side_effect = [
                requests.exceptions.Timeout("Request timed out"),
                requests.exceptions.ConnectionError("Connection failed"),
                requests.exceptions.RequestException("Generic error")
            ]
            result = validate_markdown_links(self.test_md_file)
            assert result.broken_links == 3
            assert "timed out" in str(result.errors[0]).lower()
            assert "connection" in str(result.errors[1]).lower()

    def test_redirect_handling(self):
        """Test handling of HTTP redirects."""
        markdown_content = """
        [Redirect 301](https://example.com/redirect301)
        [Redirect 302](https://example.com/redirect302)
        [Too many redirects](https://example.com/loop)
        """
        self.test_md_file.write_text(markdown_content)
        with mock.patch('requests.head') as mock_head:
            mock_head.side_effect = [
                mock.Mock(status_code=200),
                mock.Mock(status_code=200),
                requests.exceptions.TooManyRedirects("Too many redirects")
            ]
            result = validate_markdown_links(self.test_md_file)
            assert result.valid_links == 2
            assert result.broken_links == 1
            assert "redirect" in str(result.errors[0]).lower()

    def test_invalid_file_input(self):
        """Test handling of invalid file inputs."""
        with pytest.raises(FileNotFoundError):
            validate_markdown_links(Path("nonexistent.md"))
        with pytest.raises(IsADirectoryError):
            validate_markdown_links(self.temp_dir)
        txt_file = self.temp_dir / "test.txt"
        txt_file.write_text("Not markdown")
        with pytest.raises(ValueError, match="Not a markdown file"):
            validate_markdown_links(txt_file)

    def test_malformed_markdown(self):
        """Test handling of malformed markdown content."""
        malformed_content = """
        # Malformed Markdown
        [Unclosed link](file.md
        [Missing URL]
        [Nested [link](inner.md)](outer.md)
        [Malformed](url with spaces.md)
        [Empty reference][]
        [Bad reference][nonexistent]
        """
        self.test_md_file.write_text(malformed_content)
        result = validate_markdown_links(self.test_md_file)
        assert isinstance(result, LinkValidationResult)
        assert result.total_links >= 0

    def test_empty_and_whitespace_files(self):
        """Test handling of empty and whitespace-only files."""
        self.test_md_file.write_text("")
        result = validate_markdown_links(self.test_md_file)
        assert result.total_links == 0
        assert result.valid_links == 0
        assert result.broken_links == 0
        self.test_md_file.write_text("   \n\t\n   ")
        result = validate_markdown_links(self.test_md_file)
        assert result.total_links == 0

    def test_unicode_and_special_characters(self):
        """Test handling of unicode and special characters in links."""
        unicode_content = """
        # Unicode Test
        [Español](./español.md)
        [中文](./中文.md)
        [Émojis](./🚀.md)
        [Spaces and (parens)](./file with (special) chars.md)
        [Encoded URL](https://example.com/path%20with%20spaces)
        """
        self.test_md_file.write_text(unicode_content)
        (self.temp_dir / "español.md").write_text("# Español")
        (self.temp_dir / "中文.md").write_text("# 中文")
        with mock.patch('requests.head') as mock_head:
            mock_head.return_value.status_code = 200
            result = validate_markdown_links(self.test_md_file)
            assert result.total_links == 5
            assert result.valid_links >= 3

    def test_large_file_performance(self):
        """Test performance with large markdown files."""
        large_content = "# Large File\n\n"
        for i in range(100):
            large_content += f"[Link {i}](./file{i}.md)\n"
            if i < 10:
                (self.temp_dir / f"file{i}.md").write_text(f"# File {i}")
        self.test_md_file.write_text(large_content)
        import time
        start = time.time()
        result = validate_markdown_links(self.test_md_file)
        duration = time.time() - start
        assert duration < 5.0
        assert result.total_links == 100
        assert result.valid_links == 10
        assert result.broken_links == 90

    def test_concurrent_link_validation(self):
        """Test concurrent validation of multiple files."""
        files = []
        for i in range(5):
            fp = self.temp_dir / f"test{i}.md"
            content = f"# Test {i}\n[Link](./target{i}.md)\n"
            fp.write_text(content)
            files.append(fp)
            if i < 3:
                (self.temp_dir / f"target{i}.md").write_text(f"# Target {i}")
        results = validate_multiple_markdown_files(files)
        assert len(results) == 5
        valid_count = sum(1 for r in results if r.valid_links > 0)
        assert valid_count == 3

    def test_deeply_nested_links(self):
        """Test validation of deeply nested directory structures."""
        deep_path = self.temp_dir
        for i in range(5):
            deep_path = deep_path / f"level{i}"
            deep_path.mkdir()
        markdown_content = """
        # Deep Links
        [Up one](../file1.md)
        [Up two](../../file2.md)
        [Down deep](./level0/level1/level2/deep.md)
        [Absolute-ish](/file3.md)
        """
        self.test_md_file.write_text(markdown_content)
        (self.temp_dir / "level0" / "file1.md").write_text("# File 1")
        (self.temp_dir / "level0" / "level1" / "level2" / "deep.md").write_text("# Deep")
        result = validate_markdown_links(self.test_md_file)
        assert result.total_links == 4
        assert result.valid_links >= 2

    def test_link_extraction_patterns(self):
        """Test regex patterns used for link extraction."""
        test_cases = [
            ("[Simple](./file.md)", 1),
            ("[Multiple](./file1.md) and [links](./file2.md)", 2),
            ("![Image](./image.png)", 1),
            ("[Reference][ref]\n[ref]: ./file.md", 2),
            ("No links here", 0),
            ("[Empty]()", 1),
            ("Mixed [link](./file.md) and text", 1),
            ("Inline `[code](./file.md)` link", 1),
            ("[Link with\nnewline](./file.md)", 0),
        ]
        for content, expected in test_cases:
            links = extract_links_from_content(content)
            assert len(links) == expected, f"Content: {content}, got {len(links)}: {links}"

    def test_link_validation_result_structure(self):
        """Test the LinkValidationResult data structure."""
        result = LinkValidationResult()
        assert result.valid_links == 0
        assert result.broken_links == 0
        assert result.total_links == 0
        assert not result.errors
        assert not result.all_links
        result.add_valid_link("./file1.md")
        result.add_broken_link("./missing.md", "File not found")
        assert result.valid_links == 1
        assert result.broken_links == 1
        assert result.total_links == 2
        assert "./file1.md" in result.all_links
        assert "./missing.md" in result.all_links
        assert "File not found" in result.errors[0]

    def test_url_validation_helpers(self):
        """Test URL validation helper functions."""
        assert is_internal_link("./file.md")
        assert is_internal_link("../parent/file.md")
        assert is_internal_link("#anchor")
        assert not is_internal_link("https://example.com")
        assert not is_internal_link("ftp://example.com")
        assert not is_external_link("./file.md")
        assert is_external_link("https://example.com")
        assert is_external_link("http://example.com")
        assert not is_external_link("ftp://example.com")

    def test_validation_config(self):
        """Test ValidationConfig data structure."""
        config = ValidationConfig()
        assert not config.ignore_external_links
        assert not config.ignore_anchor_links
        assert config.timeout == 30
        assert config.max_retries == 3
        assert config.custom_patterns == []
        custom = ValidationConfig(ignore_external_links=True, ignore_anchor_links=True,
                                  timeout=10, max_retries=1, custom_patterns=[r'\[\[([^\]]+)\]\]'])
        assert custom.ignore_external_links
        assert custom.ignore_anchor_links
        assert custom.timeout == 10
        assert custom.max_retries == 1
        assert custom.custom_patterns

    @pytest.mark.parametrize("ignore_ext", [True, False])
    @pytest.mark.parametrize("ignore_anchor", [True, False])
    def test_validation_configuration_options(self, ignore_ext, ignore_anchor):
        """Test different configuration options for link validation."""
        markdown_content = """
        # Configuration Test
        [Internal](./file.md)
        [External](https://example.com)
        [Anchor](#section)
        """
        self.test_md_file.write_text(markdown_content)
        (self.temp_dir / "file.md").write_text("# File")
        config = ValidationConfig(ignore_external_links=ignore_ext, ignore_anchor_links=ignore_anchor)
        with mock.patch('requests.head') as mock_head:
            mock_head.return_value.status_code = 200
            result = validate_markdown_links(self.test_md_file, config)
            expected = 3 - int(ignore_ext) - int(ignore_anchor)
            assert result.total_links == expected

    def test_custom_link_patterns(self):
        """Test custom regex patterns for link detection."""
        markdown_content = """
        # Custom Patterns
        [[WikiLink]]
        ((CustomLink))
        [Normal](./normal.md)
        {{BraceLink}}
        """
        self.test_md_file.write_text(markdown_content)
        (self.temp_dir / "normal.md").write_text("# Normal")
        custom_patterns = [
            r'\[\[([^\]]+)\]\]',
            r'\(\(([^)]+)\)\)',
            r'\{\{([^}]+)\}\}',
        ]
        config = ValidationConfig(custom_patterns=custom_patterns)
        result = validate_markdown_links(self.test_md_file, config)
        assert result.total_links == 4
        assert result.valid_links == 1
        assert result.broken_links == 3

    def test_timeout_configuration(self):
        """Test timeout configuration for external links."""
        markdown_content = "[Slow link](https://example.com/slow)"
        self.test_md_file.write_text(markdown_content)
        config = ValidationConfig(timeout=1)
        with mock.patch('requests.head') as mock_head:
            mock_head.side_effect = requests.exceptions.Timeout("Timeout")
            result = validate_markdown_links(self.test_md_file, config)
            assert result.broken_links == 1
            assert "timeout" in result.errors[0].lower()

    @pytest.mark.integration
    def test_complete_workflow_with_real_files(self):
        """Integration test with a realistic file structure."""
        docs_dir = self.temp_dir / "docs"
        docs_dir.mkdir()
        readme = self.temp_dir / "README.md"
        readme_content = """
        # Project README

        See [Documentation](./docs/index.md) for details.
        Visit our [Website](https://example.com).
        Check the [API docs](./docs/api.md).
        [Missing link](./docs/missing.md)
        """
        readme.write_text(readme_content)
        index = docs_dir / "index.md"
        index_content = """
        # Documentation

        - [Getting Started](./getting-started.md)
        - [API Reference](./api.md)
        - [Examples](./examples.md)
        - [Back to README](../README.md)
        """
        index.write_text(index_content)
        (docs_dir / "getting-started.md").write_text("# Getting Started")
        (docs_dir / "api.md").write_text("# API Reference")
        with mock.patch('requests.head') as mock_head:
            mock_head.return_value.status_code = 200
            readme_result = validate_markdown_links(readme)
            index_result = validate_markdown_links(index)
            assert readme_result.total_links == 4
            assert readme_result.valid_links == 3
            assert readme_result.broken_links == 1
            assert index_result.total_links == 4
            assert index_result.valid_links == 3
            assert index_result.broken_links == 1

    def test_circular_references(self):
        """Test handling of circular references between files."""
        file1 = self.temp_dir / "file1.md"
        file2 = self.temp_dir / "file2.md"
        file3 = self.temp_dir / "file3.md"
        file1.write_text("""# File 1
        [Link to File 2](./file2.md)
        [Link to File 3](./file3.md)
        """)
        file2.write_text("""# File 2
        [Link to File 1](./file1.md)
        [Link to File 3](./file3.md)
        """)
        file3.write_text("""# File 3
        [Link to File 1](./file1.md)
        [Link to File 2](./file2.md)
        """)
        for f in [file1, file2, file3]:
            result = validate_markdown_links(f)
            assert result.valid_links == 2
            assert result.broken_links == 0

    def test_comprehensive_markdown_features(self):
        """Test validation with comprehensive markdown features."""
        comprehensive_content = """
        # Comprehensive Test

        ## Links in various contexts

        Regular [link](./regular.md) in paragraph.

        ### Headers with [links](./header.md)

        > Blockquote with [quoted link](./quote.md)

        * List item with [list link](./list.md)
          * Nested [nested link](./nested.md)

        1. Ordered list [ordered link](./ordered.md)
        2. Second item [second link](./second.md)

        | Table | Links |
        |-------|-------|
        | [Cell 1](./cell1.md) | [Cell 2](./cell2.md) |

        **Bold [bold link](./bold.md)**
        *Italic [italic link](./italic.md)*
        ~~Striked [striked link](./striked.md)~~

        [Reference link][ref]
        [Another reference][ref2]

        [ref]: ./reference.md "Reference title"
        [ref2]: https://example.com "External reference"

        Images:
        ![Alt text](./image.png)
        [![Linked image](./thumb.png)](./full.png)

        Code examples (should not be validated):
        ```
        [Code link](./code.md)
        ```

        `[Inline code link](./inline.md)`

        Final [link](./final.md).
        """
        self.test_md_file.write_text(comprehensive_content)
        for fname in ["regular.md", "header.md", "quote.md", "list.md", "nested.md",
                      "ordered.md", "second.md", "cell1.md", "cell2.md", "bold.md",
                      "italic.md", "striked.md", "reference.md", "image.png",
                      "thumb.png", "full.png", "final.md"]:
            (self.temp_dir / fname).write_text(f"# {fname}")
        with mock.patch('requests.head') as mock_head:
            mock_head.return_value.status_code = 200
            result = validate_markdown_links(self.test_md_file)
            assert result.total_links >= 15
            assert result.valid_links >= 15
            assert result.broken_links <= 2